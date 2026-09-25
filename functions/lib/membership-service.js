"use strict";

const crypto = require("crypto");
const {
  HttpError, isAdmin, isEligibleAuthUser, isEligibleDecodedIdentity,
  normalizedEmail, requireLeader, roleValue, uniqueEmails,
} = require("./access");
const { canAccessMeeting, sha256 } = require("./calendar-core");
const { acquireLocks, releaseLocks } = require("./locks");
const {
  mergeChanges, publishVisibilityChanges, removeIdentityVisibility, restoreIdentityVisibility,
} = require("./meeting-visibility");

function nowSeconds() { return Date.now() / 1000; }
const CLUB_OPERATION_RETENTION_MS = 90 * 24 * 60 * 60 * 1000;

function clubOperationIssuedAt(operationID) {
  const match = /^(\d{13})-[A-Za-z0-9_-]+$/.exec(operationID);
  return match ? Number(match[1]) : null;
}

async function cleanupCompletedClubOperations(admin, now = Date.now(), limit = 200) {
  const db = admin.database();
  const expired = await db.ref("/internal/clubOperationExpirations")
    .orderByChild("expiresAt").endAt(now).limitToFirst(limit).get();
  const updates = {};
  for (const [operationID, record] of Object.entries(expired.val() || {})) {
    if (record?.uid) updates[`internal/clubOperations/${record.uid}/${operationID}`] = null;
    updates[`internal/clubOperationExpirations/${operationID}`] = null;
  }
  if (Object.keys(updates).length) await db.ref().update(updates);
  return expired.numChildren();
}
async function resolveEmails(admin, emails) {
  const requestedEmails = uniqueEmails(emails);
  const resolved = [];
  const unresolved = [];
  const auth = admin.auth();

  // Firebase Auth accepts at most 100 identifiers in one getUsers request.
  // Resolve large club rosters in bounded batches instead of issuing one
  // network request per email; a metadata-only club edit must not time out
  // simply because that club has a long legacy member list.
  const usersByEmail = new Map();
  for (let offset = 0; offset < requestedEmails.length; offset += 100) {
    const batch = requestedEmails.slice(offset, offset + 100);
    const result = await auth.getUsers(batch.map((email) => ({ email })));
    for (const user of result.users || []) {
      const email = normalizedEmail(user.email);
      if (email) usersByEmail.set(email, user);
    }
  }
  for (const email of requestedEmails) {
    const user = usersByEmail.get(email);
    if (!user) {
      unresolved.push({ email, reason: "auth/user-not-found" });
    } else if (!isEligibleAuthUser(user, email)) {
      const reason = user.disabled ? "auth/user-disabled" :
        !user.emailVerified ? "auth/email-not-verified" : "auth/unsupported-email";
      unresolved.push({ email, reason });
    } else {
      resolved.push({ uid: user.uid, email });
    }
  }
  return { resolved, unresolved };
}

function membershipValue(person, role, oldValue) {
  const now = nowSeconds();
  return {
    role,
    email: person.email,
    emailHash: sha256(person.email),
    joinedAt: Number(oldValue?.joinedAt || now),
    updatedAt: now,
    accessRevision: oldValue?.accessRevision || 0,
  };
}

async function invalidateUserRSVPs(admin, uid, clubID, reason) {
  const db = admin.database();
  const updates = await userRSVPInvalidationUpdates(admin, uid, clubID, reason);
  if (Object.keys(updates).length) await db.ref().update(updates);
}

async function userRSVPInvalidationUpdates(admin, uid, clubID, reason) {
  const db = admin.database();
  const index = (await db.ref(`/userRSVPIndex/${uid}`).get()).val() || {};
  const updates = {};
  for (const [meetingID, value] of Object.entries(index)) {
    if (value.clubID !== clubID) continue;
    updates[`meetingRSVPs/${meetingID}/${uid}/active`] = false;
    updates[`meetingRSVPs/${meetingID}/${uid}/inactiveAt`] = nowSeconds();
    updates[`meetingRSVPs/${meetingID}/${uid}/inactiveReason`] = reason;
  }
  return updates;
}

async function writeIdentityClaim(admin, updates, person, clubID, role, state) {
  updates[`internal/identityAccess/${sha256(person.email)}/${clubID}`] = {
    email: person.email,
    role: role || null,
    state,
    lastUID: person.uid || null,
    updatedAt: nowSeconds(),
  };
}

async function appendLeaderAccessRevision(db, updates, clubID) {
  const memberships = (await db.ref(`/clubMemberships/${clubID}`).get()).val() || {};
  const projected = applyProjectedChildUpdates(
    memberships, updates, `clubMemberships/${clubID}/`
  );
  const revision = nowSeconds();
  for (const [uid, membership] of Object.entries(projected)) {
    if (roleValue(membership) === "leader") {
      const membershipPath = `userClubMemberships/${uid}/${clubID}`;
      if (Object.hasOwn(updates, membershipPath)) {
        if (updates[membershipPath] != null) {
          updates[membershipPath] = { ...updates[membershipPath], accessRevision: revision };
        }
      } else {
        updates[`${membershipPath}/accessRevision`] = revision;
      }
    }
  }
}

function applyProjectedChildUpdates(values, updates, prefix) {
  const result = { ...(values || {}) };
  if (Object.hasOwn(updates, prefix.slice(0, -1)) && updates[prefix.slice(0, -1)] == null) {
    for (const key of Object.keys(result)) delete result[key];
  }
  for (const [path, value] of Object.entries(updates)) {
    if (!path.startsWith(prefix)) continue;
    const key = path.slice(prefix.length);
    if (!key || key.includes("/")) continue;
    if (value == null) delete result[key];
    else result[key] = value;
  }
  return result;
}

async function replaceMembershipIndexes(
  admin, clubID, leaders, members,
  { commit = true, requireResolvedLeader = true } = {}
) {
  const db = admin.database();
  const [oldSnapshot, unresolvedSnapshot, leaderResolution, memberResolution] = await Promise.all([
    db.ref(`/clubMemberships/${clubID}`).get(),
    db.ref(`/internal/unresolvedIdentities/${clubID}`).get(),
    resolveEmails(admin, leaders), resolveEmails(admin, members),
  ]);
  if (requireResolvedLeader && !leaderResolution.resolved.length) {
    throw new HttpError(409, "A club must always have at least one resolved leader.");
  }
  const old = oldSnapshot.val() || {};
  const desired = {};
  for (const person of memberResolution.resolved) desired[person.uid] = membershipValue(person, "member", old[person.uid]);
  for (const person of leaderResolution.resolved) desired[person.uid] = membershipValue(person, "leader", old[person.uid]);
  const updates = {};
  const removed = [];
  for (const uid of new Set([...Object.keys(old), ...Object.keys(desired)])) {
    updates[`clubMemberships/${clubID}/${uid}`] = desired[uid] || null;
    updates[`userClubMemberships/${uid}/${clubID}`] = desired[uid] || null;
    if (desired[uid]) {
      await writeIdentityClaim(admin, updates, desired[uid], clubID, desired[uid].role, "active");
    } else {
      removed.push({ uid, ...old[uid] });
      if (old[uid]?.email) await writeIdentityClaim(admin, updates, { uid, email: old[uid].email }, clubID, old[uid].role, "revoked");
    }
  }
  for (const key of Object.keys(unresolvedSnapshot.val() || {})) {
    updates[`internal/unresolvedIdentities/${clubID}/${key}`] = null;
  }
  for (const item of [
    ...leaderResolution.unresolved.map((value) => ({ ...value, role: "leader" })),
    ...memberResolution.unresolved.map((value) => ({ ...value, role: "member" })),
  ]) {
    updates[`internal/unresolvedIdentities/${clubID}/${sha256(item.email)}`] = {
      email: item.email, role: item.role, reason: item.reason, updatedAt: nowSeconds(),
    };
    updates[`internal/identityAccess/${sha256(item.email)}/${clubID}`] = {
      email: item.email, role: item.role, state: "active", lastUID: null, updatedAt: nowSeconds(),
    };
  }
  await appendLeaderAccessRevision(db, updates, clubID);
  if (commit) {
    for (const item of removed) {
      Object.assign(updates, await userRSVPInvalidationUpdates(
        admin, item.uid, clubID, "membership-removed"
      ));
    }
    await db.ref().update(updates);
  }
  return {
    leaders: leaderResolution.resolved,
    members: memberResolution.resolved,
    unresolved: [...leaderResolution.unresolved, ...memberResolution.unresolved],
    updates,
    removed,
  };
}

async function saveClub(admin, decodedToken, request) {
  const db = admin.database();
  const incomingClub = request?.club;
  const operationID = String(request?.operationID || "").trim();
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(operationID)) {
    throw new HttpError(400, "A valid club operation ID is required.");
  }
  const issuedAt = clubOperationIssuedAt(operationID);
  if (issuedAt !== null && (issuedAt > Date.now() + 24 * 60 * 60 * 1000
      || issuedAt + CLUB_OPERATION_RETENTION_MS <= Date.now())) {
    throw new HttpError(409, "This club edit is too old to retry. Reopen the club and save it again.");
  }
  const clubID = String(incomingClub?.clubID || "").trim();
  if (/[.#$\[\]\/]/.test(clubID)) throw new HttpError(400, "Club ID contains unsupported characters.");
  if (!clubID || !incomingClub?.name?.trim()) throw new HttpError(400, "Club ID and name are required.");
  const lock = await acquireLocks(db, "calendarLocks", [clubID], 60000);
  try {
    const operationRef = db.ref(`/internal/clubOperations/${decodedToken.uid}/${operationID}`);
    const priorOperation = (await operationRef.get()).val();
    if (priorOperation) return priorOperation.result;
    const currentSnapshot = await db.ref(`/clubs/${clubID}`).get();
    const isNewClub = !currentSnapshot.exists();
    if (isNewClub) {
      if (!isAdmin(decodedToken)) throw new HttpError(403, "Only a super administrator can create a club.");
    } else {
      await requireLeader(db, clubID, decodedToken);
      const expected = Number(request?.expectedLastUpdated);
      const currentRevision = Number(currentSnapshot.child("lastUpdated").val() || 0);
      if (!Number.isFinite(expected) || expected !== currentRevision) {
        throw new HttpError(409, "This club changed on another device. Reopen it before saving again.");
      }
    }
    const leaders = uniqueEmails(incomingClub.leaders);
    const members = uniqueEmails(incomingClub.members).filter((email) => !leaders.includes(email));
    const result = await replaceMembershipIndexes(admin, clubID, leaders, members, { commit: false });
    const club = { ...incomingClub };
    delete club.meetingTimes;
    delete club.calendarStorageVersion;
    delete club.membershipStorageVersion;
    delete club.pendingMemberRequests;
    delete club.members;
    delete club.leaders;
    delete club.membersUIDs;
    delete club.leadersUIDs;
    club.clubID = clubID;
    club.name = club.name.trim();
    club.lastUpdated = nowSeconds();
    const response = { clubID, unresolved: result.unresolved };
    const updates = { ...result.updates };
    const protectedProjectionKeys = new Set([
      "meetingTimes", "calendarStorageVersion", "membershipStorageVersion",
      "pendingMemberRequests", "members", "leaders", "membersUIDs", "leadersUIDs",
    ]);
    for (const key of Object.keys(currentSnapshot.val() || {})) {
      if (!protectedProjectionKeys.has(key) && !Object.hasOwn(club, key)) {
        updates[`clubs/${clubID}/${key}`] = null;
      }
    }
    for (const [key, value] of Object.entries(club)) updates[`clubs/${clubID}/${key}`] = value;
    if (isNewClub) {
      updates[`clubCalendars/${clubID}/schemaVersion`] = 2;
      updates[`clubCalendars/${clubID}/sequence`] = 0;
      updates[`clubCalendars/${clubID}/latestChange`] = "";
      updates[`clubCalendars/${clubID}/minimumChange`] = "";
      updates[`clubCalendars/${clubID}/updatedAt`] = club.lastUpdated;
    }
    for (const item of result.removed) {
      Object.assign(updates, await userRSVPInvalidationUpdates(
        admin, item.uid, clubID, "membership-removed"
      ));
    }
    updates[`internal/clubOperations/${decodedToken.uid}/${operationID}`] = {
      clubID, completedAt: nowSeconds(), result: response,
    };
    if (issuedAt !== null) {
      updates[`internal/clubOperationExpirations/${operationID}`] = {
        uid: decodedToken.uid, expiresAt: issuedAt + CLUB_OPERATION_RETENTION_MS,
      };
    }
    await db.ref().update(updates);
    return response;
  } finally {
    await releaseLocks(lock);
  }
}

async function resolveTarget(admin, targetUID, targetEmail) {
  if (targetUID) {
    const user = await admin.auth().getUser(targetUID);
    const email = normalizedEmail(user.email || targetEmail);
    if (!isEligibleAuthUser(user, email)) {
      throw new HttpError(409, "That account is unavailable, unsupported, or not verified.");
    }
    return { uid: user.uid, email };
  }
  const email = normalizedEmail(targetEmail);
  if (!email) throw new HttpError(400, "A target user is required.");
  try {
    const user = await admin.auth().getUserByEmail(email);
    if (!isEligibleAuthUser(user, email)) {
      throw new HttpError(409, "That account is unavailable, unsupported, or not verified.");
    }
    return { uid: user.uid, email };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error?.code === "auth/user-not-found") throw new HttpError(409, "That account has not signed in to PHS Connect yet.");
    throw error;
  }
}

async function setMember(
  admin, clubID, person, role,
  { intentionalRemoval = false, clearRequest = false } = {}
) {
  const db = admin.database();
  const old = (await db.ref(`/clubMemberships/${clubID}/${person.uid}`).get()).val();
  const value = role ? membershipValue(person, role, old) : null;
  const updates = {
    [`clubMemberships/${clubID}/${person.uid}`]: value,
    [`userClubMemberships/${person.uid}/${clubID}`]: value,
  };
  await writeIdentityClaim(
    admin, updates, person, clubID, role || old?.role,
    intentionalRemoval ? "revoked" : "active"
  );
  if (clearRequest) updates[`clubJoinRequests/${clubID}/${person.uid}`] = null;
  await appendLeaderAccessRevision(db, updates, clubID);
  if (!role) Object.assign(
    updates,
    await userRSVPInvalidationUpdates(admin, person.uid, clubID, "membership-removed")
  );
  await db.ref().update(updates);
}

async function membershipAction(admin, decodedToken, body) {
  const db = admin.database();
  const clubID = String(body?.clubID || "");
  const action = String(body?.action || "");
  if (!clubID) throw new HttpError(400, "Club ID is required.");
  const lock = await acquireLocks(db, "calendarLocks", [clubID], 60000);
  try {
  const caller = { uid: decodedToken.uid, email: normalizedEmail(decodedToken.email) };
  if (["join", "request", "cancelRequest", "leave"].includes(action)) {
    if (!caller.email) throw new HttpError(400, "Your account needs an email address.");
    if (!isAdmin(decodedToken) && !isEligibleDecodedIdentity(decodedToken)) {
      throw new HttpError(403, "A verified school account is required.");
    }
    if (!(await db.ref(`/clubs/${clubID}`).get()).exists()) throw new HttpError(404, "Club not found.");
    if (action === "join") {
      if ((await db.ref(`/clubs/${clubID}/requestNeeded`).get()).val() === true) {
        throw new HttpError(409, "This club requires leader approval.");
      }
      await setMember(admin, clubID, caller, "member", { clearRequest: true });
    } else if (action === "request") {
      if ((await db.ref(`/clubs/${clubID}/requestNeeded`).get()).val() !== true) {
        throw new HttpError(409, "This club does not require a request.");
      }
      const timestamp = nowSeconds();
      const updates = {
        [`clubJoinRequests/${clubID}/${caller.uid}`]: { email: caller.email, requestedAt: timestamp, updatedAt: timestamp },
        [`userClubMemberships/${caller.uid}/${clubID}`]: { role: "pending", email: caller.email, requestedAt: timestamp, updatedAt: timestamp },
        [`internal/identityAccess/${sha256(caller.email)}/${clubID}`]: {
          email: caller.email, role: "pending", state: "pending", lastUID: caller.uid, updatedAt: timestamp,
        },
      };
      await appendLeaderAccessRevision(db, updates, clubID);
      await db.ref().update(updates);
    } else if (action === "cancelRequest") {
      const updates = {
        [`clubJoinRequests/${clubID}/${caller.uid}`]: null,
        [`userClubMemberships/${caller.uid}/${clubID}`]: null,
        [`internal/identityAccess/${sha256(caller.email)}/${clubID}`]: {
          email: caller.email, role: "pending", state: "revoked", lastUID: caller.uid, updatedAt: nowSeconds(),
        },
      };
      await appendLeaderAccessRevision(db, updates, clubID);
      await db.ref().update(updates);
    } else {
      const role = (await db.ref(`/clubMemberships/${clubID}/${caller.uid}/role`).get()).val();
      if (role === "leader") throw new HttpError(409, "Replace yourself as leader before leaving this club.");
      await setMember(admin, clubID, caller, null, { intentionalRemoval: true });
    }
    return { ok: true };
  }
  await requireLeader(db, clubID, decodedToken);
  const target = await resolveTarget(admin, body.targetUID, body.targetEmail);
  if (action === "approve") {
    await setMember(admin, clubID, target, "member", { clearRequest: true });
  } else if (action === "reject") {
    const updates = {
      [`clubJoinRequests/${clubID}/${target.uid}`]: null,
      [`userClubMemberships/${target.uid}/${clubID}`]: null,
      [`internal/identityAccess/${sha256(target.email)}/${clubID}`]: {
        email: target.email, role: "pending", state: "revoked", lastUID: target.uid, updatedAt: nowSeconds(),
      },
    };
    await appendLeaderAccessRevision(db, updates, clubID);
    await db.ref().update(updates);
  } else if (action === "remove") {
    const role = (await db.ref(`/clubMemberships/${clubID}/${target.uid}/role`).get()).val();
    if (role === "leader") throw new HttpError(409, "Replace this leader before removing them.");
    await setMember(admin, clubID, target, null, { intentionalRemoval: true });
  } else {
    throw new HttpError(400, "Unsupported membership action.");
  }
  return { ok: true };
  } finally {
    await releaseLocks(lock);
  }
}

async function accessSnapshot(admin, decodedToken, clubID) {
  const db = admin.database();
  const [ownSnapshot, membershipsSnapshot, ownRequestSnapshot] = await Promise.all([
    db.ref(`/clubMemberships/${clubID}/${decodedToken.uid}`).get(),
    db.ref(`/clubMemberships/${clubID}`).get(),
    db.ref(`/clubJoinRequests/${clubID}/${decodedToken.uid}`).get(),
  ]);
  const own = ownSnapshot.val() || null;
  const result = {
    ownMembership: own,
    ownRequest: ownRequestSnapshot.val() || null,
    memberships: membershipsSnapshot.val() || {},
  };
  if (own?.role === "leader" || isAdmin(decodedToken)) {
    result.requests = (await db.ref(`/clubJoinRequests/${clubID}`).get()).val() || {};
  }
  return result;
}

async function reconcileIdentity(admin, decodedToken) {
  if (!isEligibleDecodedIdentity(decodedToken)) return { restored: [] };
  const db = admin.database();
  const email = normalizedEmail(decodedToken.email);
  const hash = sha256(email);
  const [claimsSnapshot, currentMembershipsSnapshot, visibilityClaimsSnapshot] = await Promise.all([
    db.ref(`/internal/identityAccess/${hash}`).get(),
    db.ref(`/userClubMemberships/${decodedToken.uid}`).get(),
    db.ref(`/internal/meetingVisibilityClaims/${hash}`).get(),
  ]);
  const claims = claimsSnapshot.val() || {};
  const currentMemberships = currentMembershipsSnapshot.val() || {};
  const visibilityClaims = visibilityClaimsSnapshot.val() || {};
  const lockClubIDs = new Set();
  for (const [clubID, membership] of Object.entries(currentMemberships)) {
    if (normalizedEmail(membership.email) !== email) lockClubIDs.add(clubID);
  }
  for (const [clubID, claim] of Object.entries(claims)) {
    const existing = currentMemberships[clubID];
    if (claim.state === "pending" && claim.role === "pending") {
      if (existing?.role !== "pending" || normalizedEmail(existing.email) !== email ||
          (claim.lastUID && claim.lastUID !== decodedToken.uid)) {
        lockClubIDs.add(clubID);
      }
    } else if (claim.state === "active" && ["member", "leader"].includes(claim.role) &&
        (existing?.role !== claim.role || normalizedEmail(existing.email) !== email ||
         (claim.lastUID && claim.lastUID !== decodedToken.uid))) {
      lockClubIDs.add(clubID);
    }
  }
  const visibilityClaimsToRestore = {};
  for (const [meetingID, claim] of Object.entries(visibilityClaims)) {
    const clubID = String(claim?.clubID || "");
    if (claim?.state !== "active" || normalizedEmail(claim.email) !== email ||
        claim.lastUID === decodedToken.uid || !clubID) continue;
    visibilityClaimsToRestore[meetingID] = claim;
    lockClubIDs.add(clubID);
  }
  if (!lockClubIDs.size) return { restored: [] };
  const lock = await acquireLocks(db, "calendarLocks", lockClubIDs, 60000);
  try {
  const restored = [];
  const updates = {};
  const removedMemberships = [];
  const changedClubIDs = new Set();
  for (const [clubID, membership] of Object.entries(currentMemberships)) {
    if (normalizedEmail(membership.email) === email) continue;
    updates[`clubMemberships/${clubID}/${decodedToken.uid}`] = null;
    updates[`userClubMemberships/${decodedToken.uid}/${clubID}`] = null;
    removedMemberships.push({ uid: decodedToken.uid, clubID });
    changedClubIDs.add(clubID);
  }
  for (const [clubID, claim] of Object.entries(claims)) {
    if (claim.state === "pending" && claim.role === "pending") {
      const existing = currentMemberships[clubID];
      if (existing?.role === "pending" && normalizedEmail(existing.email) === email &&
          (!claim.lastUID || claim.lastUID === decodedToken.uid)) continue;
      const timestamp = nowSeconds();
      updates[`clubJoinRequests/${clubID}/${decodedToken.uid}`] = {
        email, requestedAt: Number(claim.updatedAt || timestamp), updatedAt: timestamp,
      };
      updates[`userClubMemberships/${decodedToken.uid}/${clubID}`] = {
        role: "pending", email, requestedAt: Number(claim.updatedAt || timestamp), updatedAt: timestamp,
      };
      if (claim.lastUID && claim.lastUID !== decodedToken.uid) {
        updates[`clubJoinRequests/${clubID}/${claim.lastUID}`] = null;
        updates[`userClubMemberships/${claim.lastUID}/${clubID}`] = null;
      }
      updates[`internal/identityAccess/${hash}/${clubID}/lastUID`] = decodedToken.uid;
      updates[`internal/identityAccess/${hash}/${clubID}/updatedAt`] = timestamp;
      changedClubIDs.add(clubID);
      continue;
    }
    if (claim.state !== "active" || !["member", "leader"].includes(claim.role)) continue;
    const existing = currentMemberships[clubID];
    if (existing?.role === claim.role && normalizedEmail(existing.email) === email &&
        (!claim.lastUID || claim.lastUID === decodedToken.uid)) continue;
    const person = { uid: decodedToken.uid, email };
    const value = membershipValue(person, claim.role, null);
    updates[`clubMemberships/${clubID}/${decodedToken.uid}`] = value;
    updates[`userClubMemberships/${decodedToken.uid}/${clubID}`] = value;
    if (claim.lastUID && claim.lastUID !== decodedToken.uid) {
      updates[`clubMemberships/${clubID}/${claim.lastUID}`] = null;
      updates[`userClubMemberships/${claim.lastUID}/${clubID}`] = null;
      removedMemberships.push({ uid: claim.lastUID, clubID });
    }
    updates[`internal/identityAccess/${hash}/${clubID}/lastUID`] = decodedToken.uid;
    updates[`internal/identityAccess/${hash}/${clubID}/updatedAt`] = nowSeconds();
    restored.push(clubID);
    changedClubIDs.add(clubID);
  }
  const visibilityChanges = await restoreIdentityVisibility(
    db, updates, hash, decodedToken.uid, email, visibilityClaimsToRestore, nowSeconds()
  );
  await publishVisibilityChanges(
    db, updates, visibilityChanges, `identity-visibility-${hash.slice(0, 16)}`, nowSeconds()
  );
  for (const clubID of changedClubIDs) await appendLeaderAccessRevision(db, updates, clubID);
  for (const item of removedMemberships) Object.assign(
    updates,
    await userRSVPInvalidationUpdates(admin, item.uid, item.clubID, "identity-changed")
  );
  if (Object.keys(updates).length) await db.ref().update(updates);
  return { restored };
  } finally {
    await releaseLocks(lock);
  }
}

async function auditAuthUser(admin, user) {
  const db = admin.database();
  const email = normalizedEmail(user.email);
  const validIdentity = isEligibleAuthUser(user);
  const memberships = (await db.ref(`/userClubMemberships/${user.uid}`).get()).val() || {};
  const stale = Object.entries(memberships).filter(([, membership]) =>
    !validIdentity || normalizedEmail(membership?.email) !== email
  );
  if (!stale.length && validIdentity) return { removed: 0 };
  const visibilityEmails = new Set([email]);
  for (const [, membership] of stale) {
    const oldEmail = normalizedEmail(membership?.email);
    if (oldEmail) visibilityEmails.add(oldEmail);
  }
  const visibilityByEmail = new Map();
  for (const value of visibilityEmails) {
    const hash = sha256(value);
    const claims = (await db.ref(`/internal/meetingVisibilityClaims/${hash}`).get()).val() || {};
    visibilityByEmail.set(value, { hash, claims });
  }
  const visibilityClubIDs = Array.from(visibilityByEmail.values()).flatMap(({ claims }) =>
    Object.values(claims).map((claim) => claim?.clubID).filter(Boolean)
  );
  const lock = await acquireLocks(
    db, "calendarLocks", [...stale.map(([clubID]) => clubID), ...visibilityClubIDs], 60000
  );
  try {
    const updates = {};
    for (const [clubID, membership] of stale) {
      updates[`userClubMemberships/${user.uid}/${clubID}`] = null;
      if (membership?.role === "pending") {
        updates[`clubJoinRequests/${clubID}/${user.uid}`] = null;
      } else {
        updates[`clubMemberships/${clubID}/${user.uid}`] = null;
        Object.assign(updates, await userRSVPInvalidationUpdates(
          admin, user.uid, clubID, validIdentity ? "identity-changed" : "identity-disabled"
        ));
      }
      const oldEmail = normalizedEmail(membership?.email);
      if (oldEmail) {
        const hash = sha256(oldEmail);
        updates[`internal/identityAccess/${hash}/${clubID}/lastUID`] = null;
        updates[`internal/identityAccess/${hash}/${clubID}/updatedAt`] = nowSeconds();
        updates[`internal/unresolvedIdentities/${clubID}/${hash}`] = {
          email: oldEmail,
          role: membership.role,
          reason: validIdentity ? "auth/email-changed" : "auth/identity-disabled",
          updatedAt: nowSeconds(),
        };
      }
      await appendLeaderAccessRevision(db, updates, clubID);
    }
    const visibilityChanges = new Map();
    for (const [claimEmail, { hash, claims }] of visibilityByEmail.entries()) {
      if (validIdentity && claimEmail === email) continue;
      mergeChanges(
        visibilityChanges,
        await removeIdentityVisibility(db, updates, hash, user.uid, claims, nowSeconds())
      );
    }
    await publishVisibilityChanges(
      db, updates, visibilityChanges, `identity-audit-${user.uid}`, nowSeconds()
    );
    if (!validIdentity) {
      const [subscriptionSnapshot, devicesSnapshot] = await Promise.all([
        db.ref(`/calendarSubscriptions/${user.uid}`).get(),
        db.ref(`/notificationDevices/${user.uid}`).get(),
      ]);
      const subscription = subscriptionSnapshot.val() || {};
      const devices = devicesSnapshot.val() || {};
      const timestamp = admin.serverTimestamp;
      updates[`notificationDevices/${user.uid}`] = null;
      updates[`notificationReadState/${user.uid}`] = null;
      updates[`internal/notificationReadStatePruneCounters/${user.uid}`] = null;
      updates[`calendarSubscriptions/${user.uid}/tokenHash`] = null;
      updates[`calendarSubscriptions/${user.uid}/revoked`] = true;
      updates[`calendarSubscriptions/${user.uid}/generation`] = Number(subscription.generation || 0) + 1;
      updates[`calendarSubscriptions/${user.uid}/updatedAt`] = timestamp;
      updates[`calendarSubscriptions/${user.uid}/revokedAt`] = timestamp;
      updates[`calendarSubscriptions/${user.uid}/cache`] = null;
      updates[`calendarSubscriptions/${user.uid}/cacheDays`] = null;
      if (subscription.tokenHash) {
        updates[`calendarTokens/${subscription.tokenHash}/valid`] = false;
        updates[`calendarTokens/${subscription.tokenHash}/revokedAt`] = timestamp;
      }
      for (const [installationID, device] of Object.entries(devices)) {
        updates[`internal/notificationInstallationOwners/${installationID}`] = null;
        if (device?.expiresDay) {
          updates[`internal/notificationDeviceExpirations/${device.expiresDay}/${expirationKeyForIdentity(user.uid, installationID)}`] = null;
        }
      }
    }
    await db.ref().update(updates);
    return { removed: stale.length };
  } finally {
    await releaseLocks(lock);
  }
}

function expirationKeyForIdentity(uid, installationID) {
  return crypto.createHash("sha256").update(`${uid}\u0000${installationID}`).digest("base64url");
}

module.exports = {
  accessSnapshot, appendLeaderAccessRevision, auditAuthUser, invalidateUserRSVPs,
  cleanupCompletedClubOperations, clubOperationIssuedAt,
  membershipAction,
  reconcileIdentity, replaceMembershipIndexes, resolveEmails, saveClub,
  userRSVPInvalidationUpdates,
};
