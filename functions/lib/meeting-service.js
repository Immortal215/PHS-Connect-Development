"use strict";

const crypto = require("crypto");
const {
  HttpError, isAdmin, isAllowedIdentityEmail, isEligibleAuthUser,
  requireLeader, requireMembership, roleValue, uniqueEmails,
} = require("./access");
const {
  addUtcDays,
  canAccessMeeting,
  dateOnlyInTimeZone,
  monthKeys,
  overlapsWindow,
  rsvpCutoffEpoch,
  validateMeeting,
  zonedMidnightEpoch,
} = require("./calendar-core");
const { loadIndexedMeetings } = require("./calendar-service");
const { SCHOOL_TIME_ZONE } = require("./constants");
const { acquireLocks, releaseLocks } = require("./locks");
const {
  syncMeetingVisibilityClaims,
} = require("./meeting-visibility");

const CALENDAR_SYNC_BODY_READ_CONCURRENCY = 8;
const MEETING_OPERATION_RETENTION_MS = 90 * 24 * 60 * 60 * 1000;
const MEETING_JOB_RETENTION_MS = 30 * 24 * 60 * 60 * 1000;

function nowSeconds() { return Date.now() / 1000; }

function normalizeVisibility(value) {
  const mode = ["public", "members", "leaders", "uids"].includes(value?.mode)
    ? value.mode : "public";
  if (mode !== "uids") return { mode };
  const uids = {};
  for (const uid of Object.keys(value?.uids || {})) if (value.uids[uid] === true) uids[uid] = true;
  return { mode, uids };
}

async function resolveMeetingVisibility(admin, input, emailResolutions = new Map()) {
  const claimsProvided = Array.isArray(input.visibilityEmails);
  const requestedMode = input.visibility?.mode || input.visibilityMode ||
    (Array.isArray(input.visibilityEmails) && input.visibilityEmails.length ? "uids" : "public");
  if (requestedMode === "public" || requestedMode === "members") {
    return { ...input, visibility: { mode: requestedMode }, __visibilityClaims: [], __visibilityClaimsProvided: true };
  }
  if (requestedMode === "leaders") {
    return { ...input, visibility: { mode: "leaders" }, __visibilityClaims: [], __visibilityClaimsProvided: true };
  }
  const uids = claimsProvided ? {} : { ...(input.visibility?.uids || {}) };
  const claims = [];
  for (const email of uniqueEmails(input.visibilityEmails)) {
    if (!isAllowedIdentityEmail(email)) {
      throw new HttpError(409, `Visibility email is not supported: ${email}`);
    }
    let resolution = emailResolutions.get(email);
    if (!resolution) {
      resolution = (async () => {
        try {
          const user = await admin.auth().getUserByEmail(email);
          return isEligibleAuthUser(user, email) ? user.uid : null;
        } catch (error) {
          if (error?.code !== "auth/user-not-found") throw error;
          return null;
        }
      })();
      emailResolutions.set(email, resolution);
    }
    const uid = await resolution;
    if (uid) uids[uid] = true;
    claims.push({ email, hash: crypto.createHash("sha256").update(email).digest("hex"), uid });
  }
  return {
    ...input,
    visibility: { mode: "uids", uids },
    __visibilityClaims: claims,
    __visibilityClaimsProvided: claimsProvided,
  };
}

function canonicalMeeting(input, { meetingID, previous = null, now }) {
  const fullDay = input.fullDay === true;
  const result = {
    meetingID,
    clubID: String(input.clubID),
    title: String(input.title || "").trim(),
    description: String(input.description || ""),
    location: String(input.location || ""),
    fullDay,
    timeZone: SCHOOL_TIME_ZONE,
    visibility: normalizeVisibility(input.visibility),
    seriesID: input.seriesID ? String(input.seriesID) : null,
    recurrenceIntervalWeeks: input.recurrenceIntervalWeeks == null
      ? null : Number(input.recurrenceIntervalWeeks),
    recurrenceEndDate: input.recurrenceEndDate || null,
    cancelled: false,
    cancelledAt: null,
    createdAt: Number(previous?.createdAt || now),
    updatedAt: now,
    revision: Number(previous?.revision || 0) + 1,
  };
  if (fullDay) {
    result.startDate = input.startDate;
    result.endDateExclusive = input.endDateExclusive;
  } else {
    result.startUtc = Number(input.startUtc);
    result.endUtc = Number(input.endUtc);
    result.startDate = dateOnlyInTimeZone(new Date(result.startUtc * 1000));
    result.endDateExclusive = addUtcDays(
      dateOnlyInTimeZone(new Date((result.endUtc - 0.001) * 1000)), 1
    );
  }
  validateMeeting(result);
  return result;
}

function meetingIndexMonths(meeting) { return monthKeys(meeting.startDate, meeting.endDateExclusive); }
function startSortValue(meeting) { return meeting.fullDay ? meeting.startDate : Number(meeting.startUtc); }

function visibilityFingerprint(value) {
  const visibility = normalizeVisibility(value);
  if (visibility.mode !== "uids") return visibility.mode;
  return `uids:${Object.keys(visibility.uids).sort().join(",")}`;
}

function occurrenceAssignments(existing, incoming, createID) {
  return incoming.map((input, index) => ({
    input,
    previous: existing[index] || null,
    meetingID: existing[index]?.meetingID || input.meetingID || createID(),
  }));
}

function sameOccurrenceRevisions(first, second) {
  return first.length === second.length && first.every((item, index) =>
    item.meetingID === second[index]?.meetingID &&
    Number(item.revision || 0) === Number(second[index]?.revision || 0)
  );
}

function legacyDateString(epochSeconds) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: SCHOOL_TIME_ZONE, year: "numeric", month: "2-digit", day: "2-digit",
    hour: "numeric", minute: "2-digit", hour12: true,
  }).formatToParts(new Date(epochSeconds * 1000));
  const value = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${value.month}-${value.day}-${value.year}, ${value.hour}:${value.minute} ${value.dayPeriod}`;
}

function clientMeeting(meeting) {
  if (!meeting) return meeting;
  const startEpoch = meeting.fullDay ? zonedMidnightEpoch(meeting.startDate) : Number(meeting.startUtc);
  const endEpoch = meeting.fullDay
    ? zonedMidnightEpoch(addUtcDays(meeting.endDateExclusive, -1)) : Number(meeting.endUtc);
  return { ...meeting, startTime: legacyDateString(startEpoch), endTime: legacyDateString(endEpoch) };
}

function changeMetadata(meeting, operation) {
  return {
    meetingID: meeting.meetingID,
    operation,
    meetingRevision: meeting.revision,
    startDate: meeting.startDate,
    endDateExclusive: meeting.endDateExclusive,
    updatedAt: meeting.updatedAt,
  };
}

function applyMeetingIndexUpdates(updates, oldMeeting, newMeeting) {
  const oldMonths = oldMeeting ? meetingIndexMonths(oldMeeting) : [];
  const newMonths = newMeeting ? meetingIndexMonths(newMeeting) : [];
  if (oldMeeting) {
    for (const key of oldMonths) {
      if (!newMeeting || oldMeeting.clubID !== newMeeting.clubID || !newMonths.includes(key)) {
        updates[`clubCalendars/${oldMeeting.clubID}/months/${key}/${oldMeeting.meetingID}`] = null;
      }
    }
  }
  if (newMeeting) {
    for (const key of newMonths) {
      updates[`clubCalendars/${newMeeting.clubID}/months/${key}/${newMeeting.meetingID}`] = newMeeting.revision;
    }
  }
}

async function readMeeting(db, clubID, meetingID) {
  if (!clubID || !meetingID) return null;
  const snapshot = await db.ref(`/clubMeetings/${clubID}/${meetingID}`).get();
  const value = snapshot.val();
  return value ? { ...value, clubID, meetingID } : null;
}

async function compactCalendarChanges(admin, clubID, keep = 500) {
  const db = admin.database();
  const changesRef = db.ref(`/clubCalendars/${clubID}/changes`);
  const tail = await changesRef.orderByKey().limitToLast(keep + 1).get();
  const keys = Object.keys(tail.val() || {}).sort();
  if (keys.length <= keep) return { removed: 0, minimumChange: keys[0] || "" };
  const proposedMinimum = keys[keys.length - keep];
  const minimumResult = await db.ref(`/clubCalendars/${clubID}/minimumChange`).transaction(
    (current) => !current || current < proposedMinimum ? proposedMinimum : current,
    undefined,
    false
  );
  const minimumChange = minimumResult.snapshot.val() || proposedMinimum;
  let removed = 0;
  // Publish the new floor before deleting. A concurrent client behind that
  // floor will take a bounded snapshot instead of observing a hole in the log.
  while (removed < 5000) {
    const page = await changesRef.orderByKey().endBefore(minimumChange).limitToFirst(250).get();
    const pageKeys = Object.keys(page.val() || {});
    if (!pageKeys.length) break;
    const updates = Object.fromEntries(pageKeys.map((key) => [key, null]));
    await changesRef.update(updates);
    removed += pageKeys.length;
    if (pageKeys.length < 250) break;
  }
  return { removed, minimumChange };
}

async function readSeries(db, clubID, seriesID) {
  const snapshot = await db.ref(`/clubMeetings/${clubID}`)
    .orderByChild("seriesID").equalTo(seriesID).get();
  return Object.entries(snapshot.val() || {})
    .map(([meetingID, value]) => ({ ...value, clubID, meetingID }))
    .sort((a, b) => startSortValue(a) < startSortValue(b) ? -1 : 1);
}

async function acquireOperation(db, operationID, actorUID, kind) {
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(operationID || "")) {
    throw new HttpError(400, "A valid operation ID is required.");
  }
  const expiresAt = operationExpiresAt(operationID);
  if (expiresAt !== null && Date.now() >= expiresAt) {
    throw new HttpError(409, "This operation ID expired. Start a new edit.");
  }
  if (expiresAt !== null && expiresAt > Date.now() + MEETING_OPERATION_RETENTION_MS + 24 * 60 * 60 * 1000) {
    throw new HttpError(400, "The operation ID timestamp is too far in the future.");
  }
  const ref = db.ref(`/internal/meetingOperations/${operationID}`);
  const existing = (await ref.get()).val();
  if (existing && (existing.actorUID !== actorUID || existing.kind !== kind)) {
    throw new HttpError(409, "This operation ID was already used for another request.");
  }
  if (existing?.status === "complete") return { completed: existing.result };
  const owner = crypto.randomUUID();
  const now = Date.now();
  const result = await ref.transaction((current) => {
    if (current?.status === "complete") return;
    if (current?.expiresAt > now) return;
    return { status: "running", owner, actorUID, kind, expiresAt: now + 60000 };
  }, undefined, false);
  const value = result.snapshot.val();
  if (value?.status === "complete") return { completed: value.result };
  if (!result.committed || value?.owner !== owner) throw new HttpError(409, "This save is already in progress.");
  return { ref, owner };
}

function operationExpiresAt(operationID) {
  const match = /^t(\d{13})-[0-9a-fA-F-]{36}$/.exec(String(operationID || ""));
  return match ? Number(match[1]) + MEETING_OPERATION_RETENTION_MS : null;
}

function appendOperationExpiration(updates, operationID) {
  const expiresAt = operationExpiresAt(operationID);
  if (expiresAt !== null) updates[`internal/meetingOperationExpirations/${operationID}`] = expiresAt;
}

async function completeMeetingNotificationJob(db, jobID, serverTimestamp) {
  const updates = {
    [`internal/meetingNotificationJobs/${jobID}/status`]: "complete",
    [`internal/meetingNotificationJobs/${jobID}/completedAt`]: serverTimestamp,
    [`internal/meetingNotificationJobs/${jobID}/owner`]: null,
    [`internal/meetingNotificationJobs/${jobID}/leaseExpiresAt`]: null,
    [`internal/meetingNotificationJobExpirations/${jobID}`]: Date.now() + MEETING_JOB_RETENTION_MS,
  };
  await db.ref().update(updates);
}

async function cleanupCompletedMeetingRecords(admin, now = Date.now(), limit = 200) {
  const db = admin.database();
  const [operations, jobs] = await Promise.all([
    db.ref("/internal/meetingOperationExpirations").orderByValue().endAt(now).limitToFirst(limit).get(),
    db.ref("/internal/meetingNotificationJobExpirations").orderByValue().endAt(now).limitToFirst(limit).get(),
  ]);
  const updates = {};
  for (const operationID of Object.keys(operations.val() || {})) {
    updates[`internal/meetingOperations/${operationID}`] = null;
    updates[`internal/meetingOperationExpirations/${operationID}`] = null;
  }
  for (const jobID of Object.keys(jobs.val() || {})) {
    updates[`internal/meetingNotificationJobs/${jobID}`] = null;
    updates[`internal/meetingNotificationJobExpirations/${jobID}`] = null;
  }
  if (Object.keys(updates).length) await db.ref().update(updates);
  return { operations: operations.numChildren(), jobs: jobs.numChildren() };
}

async function calendarSequences(db, clubIDs) {
  const values = {};
  for (const clubID of clubIDs) {
    const sequence = Number((await db.ref(`/clubCalendars/${clubID}/sequence`).get()).val() || 0) + 1;
    values[clubID] = { sequence, cursor: String(sequence).padStart(16, "0") };
  }
  return values;
}

async function appendRSVPRevalidation(db, updates, meeting, memberships) {
  const responses = (await db.ref(`/meetingRSVPs/${meeting.meetingID}`).get()).val() || {};
  for (const [uid, response] of Object.entries(responses)) {
    if (response.active === false) continue;
    if (!canAccessMeeting(meeting, roleValue(memberships[uid]), uid)) {
      updates[`meetingRSVPs/${meeting.meetingID}/${uid}/active`] = false;
      updates[`meetingRSVPs/${meeting.meetingID}/${uid}/inactiveAt`] = nowSeconds();
      updates[`meetingRSVPs/${meeting.meetingID}/${uid}/inactiveReason`] = "access-lost";
    } else {
      updates[`userRSVPIndex/${uid}/${meeting.meetingID}/clubID`] = meeting.clubID;
    }
  }
}

async function appendRSVPCancellation(db, updates, meeting) {
  const responses = (await db.ref(`/meetingRSVPs/${meeting.meetingID}`).get()).val() || {};
  const changedAt = nowSeconds();
  for (const [uid, response] of Object.entries(responses)) {
    if (response.active === false) continue;
    updates[`meetingRSVPs/${meeting.meetingID}/${uid}/active`] = false;
    updates[`meetingRSVPs/${meeting.meetingID}/${uid}/inactiveAt`] = changedAt;
    updates[`meetingRSVPs/${meeting.meetingID}/${uid}/inactiveReason`] = "meeting-cancelled";
  }
}

async function saveMeetings(admin, decodedToken, body) {
  const db = admin.database();
  const incoming = Array.isArray(body?.meetings) ? body.meetings : [];
  if (!incoming.length) throw new HttpError(400, "At least one meeting is required.");
  const replacingClubID = body.replacingClubID || incoming[0].clubID;
  const replacingID = body.replacingMeetingID || null;
  const anchor = replacingID ? await readMeeting(db, replacingClubID, replacingID) : null;
  if (replacingID && !anchor) throw new HttpError(404, "The meeting no longer exists.");
  const clubIDs = Array.from(new Set([
    ...incoming.map((meeting) => String(meeting.clubID)), ...(anchor ? [anchor.clubID] : []),
  ])).sort();
  for (const clubID of clubIDs) await requireLeader(db, clubID, decodedToken);
  const operation = await acquireOperation(db, body.operationID, decodedToken.uid, "save");
  if (operation.completed) return operation.completed;
  let affected = anchor ? [anchor] : [];
  if (anchor && body.includingFuture === true && anchor.seriesID) {
    affected = (await readSeries(db, anchor.clubID, anchor.seriesID))
      .filter((meeting) => !meeting.cancelled && startSortValue(meeting) >= startSortValue(anchor));
  }
  let meetingLock = null;
  let calendarLock = null;
  try {
    meetingLock = await acquireLocks(db, "meetingLocks", affected.map((item) => item.meetingID));
    calendarLock = await acquireLocks(db, "calendarLocks", clubIDs, 60000);
    for (const clubID of clubIDs) {
      const schemaVersion = Number((await db.ref(`/clubCalendars/${clubID}/schemaVersion`).get()).val() || 0);
      if (schemaVersion < 2) {
        throw new HttpError(409, "This club calendar must be upgraded by a super administrator before editing.");
      }
    }
    const freshAnchor = anchor ? await readMeeting(db, anchor.clubID, anchor.meetingID) : null;
    const freshAffected = freshAnchor && body.includingFuture === true && freshAnchor.seriesID
      ? (await readSeries(db, freshAnchor.clubID, freshAnchor.seriesID)).filter(
        (item) => !item.cancelled && startSortValue(item) >= startSortValue(freshAnchor)
      )
      : freshAnchor ? [freshAnchor] : [];
    if (!sameOccurrenceRevisions(affected, freshAffected)) {
      throw new HttpError(409, "A meeting in this series changed elsewhere. Refresh and try again.");
    }
    if (freshAnchor && body.expectedRevision != null &&
        Number(freshAnchor.revision) !== Number(body.expectedRevision)) {
      throw new HttpError(409, "This meeting changed elsewhere. Refresh and try again.");
    }

    const sequences = await calendarSequences(db, clubIDs);
    const now = nowSeconds();
    const emailResolutions = new Map();
    const resolvedIncoming = await Promise.all(incoming.map(
      (item) => resolveMeetingVisibility(admin, item, emailResolutions)
    ));
    const sortedIncoming = [...resolvedIncoming].sort((a, b) => {
      const av = a.fullDay ? a.startDate : Number(a.startUtc);
      const bv = b.fullDay ? b.startDate : Number(b.startUtc);
      return av < bv ? -1 : av > bv ? 1 : 0;
    });
    const updates = {};
    const saved = [];
    const membershipSnapshots = new Map();
    const changesByClub = Object.fromEntries(clubIDs.map((id) => [id, []]));
    const assignments = occurrenceAssignments(
      affected,
      sortedIncoming,
      () => db.ref("/clubMeetings").push().key
    );
    for (const assignment of assignments) {
      const old = assignment.previous;
      const meetingID = assignment.meetingID;
      const next = canonicalMeeting(assignment.input, { meetingID, previous: old, now });
      if (old && old.clubID !== next.clubID) updates[`clubMeetings/${old.clubID}/${meetingID}`] = null;
      updates[`clubMeetings/${next.clubID}/${meetingID}`] = next;
      applyMeetingIndexUpdates(updates, old, next);
      await syncMeetingVisibilityClaims(db, updates, {
        meetingID,
        oldClubID: old?.clubID || null,
        newClubID: next.clubID,
        mode: next.visibility.mode,
        claims: assignment.input.__visibilityClaims,
        claimsProvided: assignment.input.__visibilityClaimsProvided,
        cancelled: false,
        timestamp: now,
      });
      changesByClub[next.clubID].push(changeMetadata(next, "upsert"));
      if (old && old.clubID !== next.clubID) changesByClub[old.clubID].push(changeMetadata(old, "delete"));
      const accessChanged = old && (
        old.clubID !== next.clubID ||
        visibilityFingerprint(old.visibility) !== visibilityFingerprint(next.visibility) ||
        Boolean(old.cancelled) !== Boolean(next.cancelled)
      );
      if (accessChanged) {
        let memberships = membershipSnapshots.get(next.clubID);
        if (!memberships) {
          memberships = db.ref(`/clubMemberships/${next.clubID}`).get()
            .then((snapshot) => snapshot.val() || {});
          membershipSnapshots.set(next.clubID, memberships);
        }
        await appendRSVPRevalidation(db, updates, next, await memberships);
      }
      saved.push(next);
    }
    for (const old of affected.slice(sortedIncoming.length)) {
      const cancelled = { ...old, cancelled: true, cancelledAt: now, updatedAt: now, revision: Number(old.revision || 0) + 1 };
      updates[`clubMeetings/${old.clubID}/${old.meetingID}`] = cancelled;
      applyMeetingIndexUpdates(updates, old, cancelled);
      await syncMeetingVisibilityClaims(db, updates, {
        meetingID: old.meetingID,
        oldClubID: old.clubID,
        newClubID: old.clubID,
        mode: old.visibility?.mode || "public",
        claims: [],
        claimsProvided: true,
        cancelled: true,
        timestamp: now,
      });
      changesByClub[old.clubID].push(changeMetadata(cancelled, "cancel"));
      await appendRSVPCancellation(db, updates, cancelled);
    }
    for (const clubID of clubIDs) {
      const sequence = sequences[clubID];
      updates[`clubCalendars/${clubID}/sequence`] = sequence.sequence;
      updates[`clubCalendars/${clubID}/latestChange`] = sequence.cursor;
      updates[`clubCalendars/${clubID}/updatedAt`] = now;
      updates[`clubCalendars/${clubID}/changes/${sequence.cursor}`] = {
        operationID: body.operationID, committedAt: now, items: changesByClub[clubID],
      };
    }
    const result = { meetings: saved.map(clientMeeting) };
    updates[`internal/meetingOperations/${body.operationID}`] = {
      status: "complete", actorUID: decodedToken.uid, kind: "save", completedAt: now, result,
    };
    appendOperationExpiration(updates, body.operationID);
    updates[`internal/meetingNotificationJobs/${body.operationID}`] = {
      clubID: saved[0].clubID, meetingID: saved[0].meetingID,
      kind: anchor ? "updated" : "created", repeating: Boolean(saved[0].seriesID), createdAt: now,
    };
    await db.ref().update(updates);
    return result;
  } catch (error) {
    await operation.ref.transaction((value) => value?.owner === operation.owner ? null : value, undefined, false);
    throw error;
  } finally {
    if (calendarLock) await releaseLocks(calendarLock);
    if (meetingLock) await releaseLocks(meetingLock);
  }
}

async function deleteMeetings(admin, decodedToken, body) {
  const db = admin.database();
  const meeting = await readMeeting(db, body?.clubID, body?.meetingID);
  if (!meeting) throw new HttpError(404, "The meeting no longer exists.");
  await requireLeader(db, meeting.clubID, decodedToken);
  const operation = await acquireOperation(db, body.operationID, decodedToken.uid, "delete");
  if (operation.completed) return operation.completed;
  let affected = [meeting];
  if (body.includingFuture === true && meeting.seriesID) {
    affected = (await readSeries(db, meeting.clubID, meeting.seriesID))
      .filter((item) => !item.cancelled && startSortValue(item) >= startSortValue(meeting));
  }
  let meetingLock = null;
  let calendarLock = null;
  try {
    meetingLock = await acquireLocks(db, "meetingLocks", affected.map((item) => item.meetingID));
    calendarLock = await acquireLocks(db, "calendarLocks", [meeting.clubID], 60000);
    const schemaVersion = Number(
      (await db.ref(`/clubCalendars/${meeting.clubID}/schemaVersion`).get()).val() || 0
    );
    if (schemaVersion < 2) {
      throw new HttpError(409, "This club calendar must be upgraded by a super administrator before editing.");
    }
    const freshMeeting = await readMeeting(db, meeting.clubID, meeting.meetingID);
    const freshAffected = freshMeeting && body.includingFuture === true && freshMeeting.seriesID
      ? (await readSeries(db, freshMeeting.clubID, freshMeeting.seriesID)).filter(
        (item) => !item.cancelled && startSortValue(item) >= startSortValue(freshMeeting)
      )
      : freshMeeting ? [freshMeeting] : [];
    if (!sameOccurrenceRevisions(affected, freshAffected)) {
      throw new HttpError(409, "A meeting in this series changed elsewhere. Refresh and try again.");
    }
    const sequence = (await calendarSequences(db, [meeting.clubID]))[meeting.clubID];
    const now = nowSeconds();
    const updates = {};
    const items = [];
    for (const old of affected) {
      const cancelled = { ...old, cancelled: true, cancelledAt: now, updatedAt: now, revision: Number(old.revision || 0) + 1 };
      updates[`clubMeetings/${old.clubID}/${old.meetingID}`] = cancelled;
      applyMeetingIndexUpdates(updates, old, cancelled);
      await syncMeetingVisibilityClaims(db, updates, {
        meetingID: old.meetingID,
        oldClubID: old.clubID,
        newClubID: old.clubID,
        mode: old.visibility?.mode || "public",
        claims: [],
        claimsProvided: true,
        cancelled: true,
        timestamp: now,
      });
      items.push(changeMetadata(cancelled, "cancel"));
      await appendRSVPCancellation(db, updates, cancelled);
    }
    updates[`clubCalendars/${meeting.clubID}/sequence`] = sequence.sequence;
    updates[`clubCalendars/${meeting.clubID}/latestChange`] = sequence.cursor;
    updates[`clubCalendars/${meeting.clubID}/updatedAt`] = now;
    updates[`clubCalendars/${meeting.clubID}/changes/${sequence.cursor}`] = {
      operationID: body.operationID, committedAt: now, items,
    };
    const result = { deleted: affected.map((item) => item.meetingID) };
    updates[`internal/meetingOperations/${body.operationID}`] = {
      status: "complete", actorUID: decodedToken.uid, kind: "delete", completedAt: now, result,
    };
    appendOperationExpiration(updates, body.operationID);
    await db.ref().update(updates);
    return result;
  } catch (error) {
    await operation.ref.transaction((value) => value?.owner === operation.owner ? null : value, undefined, false);
    throw error;
  } finally {
    if (calendarLock) await releaseLocks(calendarLock);
    if (meetingLock) await releaseLocks(meetingLock);
  }
}

async function handleDeletedClub(admin, clubID, deletedClub = {}) {
  const db = admin.database();
  const lock = await acquireLocks(db, "calendarLocks", [clubID], 60000);
  try {
    const existingMarker = (await db.ref(`/internal/deletedClubs/${clubID}`).get()).val();
    if (existingMarker?.completedAt) return existingMarker.result || {};
    const [meetingsSnapshot, membershipsSnapshot, requestsSnapshot, unresolvedSnapshot] = await Promise.all([
      db.ref(`/clubMeetings/${clubID}`).get(),
      db.ref(`/clubMemberships/${clubID}`).get(),
      db.ref(`/clubJoinRequests/${clubID}`).get(),
      db.ref(`/internal/unresolvedIdentities/${clubID}`).get(),
    ]);
    const meetings = meetingsSnapshot.val() || {};
    const memberships = membershipsSnapshot.val() || {};
    const requests = requestsSnapshot.val() || {};
    const unresolved = unresolvedSnapshot.val() || {};
    const now = nowSeconds();
    const updates = {
      [`clubMemberships/${clubID}`]: null,
      [`clubJoinRequests/${clubID}`]: null,
      [`internal/unresolvedIdentities/${clubID}`]: null,
    };
    const sequence = (await calendarSequences(db, [clubID]))[clubID];
    const items = [];
    for (const [meetingID, value] of Object.entries(meetings)) {
      const old = { ...value, clubID, meetingID };
      const cancelled = {
        ...old, cancelled: true, cancelledAt: now, updatedAt: now,
        revision: Number(old.revision || 0) + 1,
      };
      updates[`clubMeetings/${clubID}/${meetingID}`] = cancelled;
      applyMeetingIndexUpdates(updates, old, cancelled);
      await syncMeetingVisibilityClaims(db, updates, {
        meetingID,
        oldClubID: clubID,
        newClubID: clubID,
        mode: old.visibility?.mode || "public",
        claims: [],
        claimsProvided: true,
        cancelled: true,
        timestamp: now,
      });
      items.push(changeMetadata(cancelled, "cancel"));
      await appendRSVPCancellation(db, updates, cancelled);
    }
    for (const [uid, membership] of Object.entries(memberships)) {
      updates[`userClubMemberships/${uid}/${clubID}`] = null;
      if (membership?.email) {
        const hash = crypto.createHash("sha256").update(String(membership.email).trim().toLowerCase()).digest("hex");
        updates[`internal/identityAccess/${hash}/${clubID}/state`] = "revoked";
        updates[`internal/identityAccess/${hash}/${clubID}/updatedAt`] = now;
      }
    }
    for (const [uid, request] of Object.entries(requests)) {
      updates[`userClubMemberships/${uid}/${clubID}`] = null;
      if (request?.email) {
        const hash = crypto.createHash("sha256").update(String(request.email).trim().toLowerCase()).digest("hex");
        updates[`internal/identityAccess/${hash}/${clubID}/state`] = "revoked";
        updates[`internal/identityAccess/${hash}/${clubID}/updatedAt`] = now;
      }
    }
    for (const [hash] of Object.entries(unresolved)) {
      updates[`internal/identityAccess/${hash}/${clubID}/state`] = "revoked";
      updates[`internal/identityAccess/${hash}/${clubID}/updatedAt`] = now;
    }
    const chatIDs = Array.isArray(deletedClub.chatIDs)
      ? deletedClub.chatIDs : Object.values(deletedClub.chatIDs || {});
    for (const chatID of chatIDs.filter(Boolean)) updates[`chats/${chatID}`] = null;
    updates[`clubCalendars/${clubID}/sequence`] = sequence.sequence;
    updates[`clubCalendars/${clubID}/latestChange`] = sequence.cursor;
    updates[`clubCalendars/${clubID}/updatedAt`] = now;
    updates[`clubCalendars/${clubID}/changes/${sequence.cursor}`] = {
      operationID: `club-delete-${sequence.cursor}`,
      committedAt: now,
      items,
    };
    const result = {
      cancelledMeetings: items.length,
      removedMemberships: Object.keys(memberships).length,
    };
    updates[`internal/deletedClubs/${clubID}`] = {
      deletedAt: now, completedAt: now, result,
    };
    await db.ref().update(updates);
    return result;
  } finally {
    await releaseLocks(lock);
  }
}

async function nextPublicMeeting(admin, clubID) {
  const db = admin.database();
  const today = dateOnlyInTimeZone(new Date());
  const endDateExclusive = addUtcDays(today, 367);
  const now = nowSeconds();
  const seenMeetingIDs = new Set();
  for (const monthKey of monthKeys(today, endDateExclusive)) {
    const index = (await db.ref(`/clubCalendars/${clubID}/months/${monthKey}`).get()).val() || {};
    const meetingIDs = Object.keys(index).filter((meetingID) => !seenMeetingIDs.has(meetingID));
    const meetings = [];
    for (let offset = 0; offset < meetingIDs.length; offset += 25) {
      const chunk = meetingIDs.slice(offset, offset + 25);
      const values = await Promise.all(chunk.map(async (meetingID) => {
        const meeting = await readMeeting(db, clubID, meetingID);
        if (!meeting) throw new Error(`Calendar index points to missing meeting ${meetingID}.`);
        return meeting;
      }));
      meetings.push(...values);
    }
    meetings.sort((first, second) => {
      const firstStart = rsvpCutoffEpoch(first);
      const secondStart = rsvpCutoffEpoch(second);
      if (firstStart === secondStart) return String(first.meetingID).localeCompare(String(second.meetingID));
      return firstStart < secondStart ? -1 : 1;
    });
    const monthStart = `${monthKey}-01`;
    const nextMonthStart = `${addUtcDays(monthStart, 32).slice(0, 7)}-01`;
    const monthWindow = {
      startDate: monthStart < today ? today : monthStart,
      endDateExclusive: nextMonthStart > endDateExclusive ? endDateExclusive : nextMonthStart,
    };
    for (const meeting of meetings) {
      if (!overlapsWindow(meeting, monthWindow)) continue;
      seenMeetingIDs.add(meeting.meetingID);
      if (!meeting.cancelled && (meeting.visibility?.mode || "public") === "public" &&
          rsvpCutoffEpoch(meeting) >= now) {
        return clientMeeting(meeting);
      }
    }
  }
  return null;
}

async function syncClubCalendar(admin, decodedToken, query) {
  const db = admin.database();
  const clubID = String(query.clubID || "");
  const role = isAdmin(decodedToken) ? "leader" : await requireMembership(db, clubID, decodedToken);
  const [latestSnapshot, minimumSnapshot] = await Promise.all([
    db.ref(`/clubCalendars/${clubID}/latestChange`).get(),
    db.ref(`/clubCalendars/${clubID}/minimumChange`).get(),
  ]);
  const latestChange = latestSnapshot.val() || "";
  const minimumChange = minimumSnapshot.val() || "";
  const after = String(query.after || "");
  const startDate = String(query.start || dateOnlyInTimeZone(new Date()));
  const endDateExclusive = String(query.end || addUtcDays(startDate, 367));
  if (!after || (minimumChange && after < minimumChange)) {
    const meetings = (await loadIndexedMeetings(db, [clubID], { startDate, endDateExclusive }))
      .filter((meeting) => !meeting.cancelled && canAccessMeeting(meeting, role, decodedToken.uid));
    return { mode: "snapshot", latestChange, meetings: meetings.map(clientMeeting) };
  }
  if (after === latestChange) return { mode: "delta", latestChange, changes: [], hasMore: false };
  const target = String(query.target || latestChange);
  const limit = Math.min(200, Math.max(1, Number(query.limit || 100)));
  const snapshot = await db.ref(`/clubCalendars/${clubID}/changes`)
    .orderByKey().startAfter(after).endAt(target).limitToFirst(limit + 1).get();
  const entries = Object.entries(snapshot.val() || {});
  const page = entries.slice(0, limit);
  const collapsed = new Map();
  for (const [, change] of page) for (const item of change.items || []) collapsed.set(item.meetingID, item);
  const items = Array.from(collapsed.values());
  const changes = new Array(items.length);
  const bodyReadIndexes = [];
  for (let index = 0; index < items.length; index += 1) {
    const item = items[index];
    if (item.operation !== "upsert") {
      changes[index] = {
        meetingID: item.meetingID,
        operation: item.operation === "cancel" ? "cancel" : "delete",
        meetingRevision: item.meetingRevision,
      };
      continue;
    }
    const hasRangeMetadata = typeof item.startDate === "string" &&
      typeof item.endDateExclusive === "string";
    if (hasRangeMetadata &&
        (item.startDate >= endDateExclusive || item.endDateExclusive <= startDate)) {
      changes[index] = {
        meetingID: item.meetingID, operation: "delete", meetingRevision: item.meetingRevision,
      };
      continue;
    }
    bodyReadIndexes.push(index);
  }
  for (let offset = 0; offset < bodyReadIndexes.length;
    offset += CALENDAR_SYNC_BODY_READ_CONCURRENCY) {
    const indexes = bodyReadIndexes.slice(offset, offset + CALENDAR_SYNC_BODY_READ_CONCURRENCY);
    const meetings = await Promise.all(indexes.map((index) =>
      readMeeting(db, clubID, items[index].meetingID)));
    for (let index = 0; index < indexes.length; index += 1) {
      const changeIndex = indexes[index];
      const item = items[changeIndex];
      const meeting = meetings[index];
      if (!meeting || !overlapsWindow(meeting, { startDate, endDateExclusive }) ||
          !canAccessMeeting(meeting, role, decodedToken.uid)) {
        changes[changeIndex] = {
          meetingID: item.meetingID, operation: "delete", meetingRevision: item.meetingRevision,
        };
      } else {
        changes[changeIndex] = {
          meetingID: item.meetingID, operation: meeting.cancelled ? "cancel" : "upsert",
          meetingRevision: meeting.revision, meeting: clientMeeting(meeting),
        };
      }
    }
  }
  return {
    mode: "delta", latestChange, target, changes,
    hasMore: entries.length > limit,
    nextCursor: page.length ? page[page.length - 1][0] : after,
  };
}

async function assertMeetingAccess(db, decodedToken, meeting) {
  const role = await requireMembership(db, meeting.clubID, decodedToken);
  if (!canAccessMeeting(meeting, role, decodedToken.uid)) throw new HttpError(403, "You cannot respond to this meeting.");
  return role;
}

async function setRSVP(admin, decodedToken, body) {
  const db = admin.database();
  const meetingID = String(body?.meetingID || "");
  const clubID = String(body?.clubID || "");
  if (!meetingID || !clubID) throw new HttpError(400, "A club and meeting are required.");
  const meetingLock = await acquireLocks(db, "meetingLocks", [meetingID], 15000);
  try {
    const lock = await acquireLocks(db, "rsvpLocks", [`${meetingID}_${decodedToken.uid}`], 15000);
    try {
      const meeting = await readMeeting(db, clubID, meetingID);
      if (!meeting || meeting.cancelled) throw new HttpError(409, "This meeting is no longer accepting responses.");
      await assertMeetingAccess(db, decodedToken, meeting);
      if (nowSeconds() >= rsvpCutoffEpoch(meeting)) throw new HttpError(409, "RSVP changes closed when this meeting started.");
      const status = body.status == null ? null : String(body.status);
      if (status !== null && !["going", "maybe", "notGoing"].includes(status)) throw new HttpError(400, "Invalid RSVP response.");
      const updates = {};
      if (status === null) {
        updates[`meetingRSVPs/${meeting.meetingID}/${decodedToken.uid}`] = null;
        updates[`userRSVPIndex/${decodedToken.uid}/${meeting.meetingID}`] = null;
      } else {
        updates[`meetingRSVPs/${meeting.meetingID}/${decodedToken.uid}`] = {
          status, active: true, updatedAt: nowSeconds(), meetingRevision: meeting.revision,
        };
        updates[`userRSVPIndex/${decodedToken.uid}/${meeting.meetingID}`] = { clubID: meeting.clubID };
      }
      await db.ref().update(updates);
      const freshMeeting = await readMeeting(db, meeting.clubID, meeting.meetingID);
      try {
        if (!freshMeeting || freshMeeting.cancelled) throw new Error("inactive");
        await assertMeetingAccess(db, decodedToken, freshMeeting);
      } catch {
        if (status !== null) await db.ref(`/meetingRSVPs/${meeting.meetingID}/${decodedToken.uid}`).update({
          active: false, inactiveAt: nowSeconds(), inactiveReason: "access-lost",
        });
        throw new HttpError(409, "Access changed while saving. Your previous response was retained as inactive.");
      }
      return { status };
    } finally {
      await releaseLocks(lock);
    }
  } finally {
    await releaseLocks(meetingLock);
  }
}

async function getRSVP(admin, decodedToken, clubID, meetingID) {
  const db = admin.database();
  const meeting = await readMeeting(db, clubID, meetingID);
  if (!meeting || meeting.cancelled) throw new HttpError(404, "Meeting not found.");
  await assertMeetingAccess(db, decodedToken, meeting);
  return (await db.ref(`/meetingRSVPs/${meetingID}/${decodedToken.uid}`).get()).val() || null;
}

async function listRSVPs(admin, decodedToken, clubID, meetingID) {
  const db = admin.database();
  const meeting = await readMeeting(db, clubID, meetingID);
  if (!meeting) throw new HttpError(404, "Meeting not found.");
  await requireLeader(db, clubID, decodedToken);
  const [responsesSnapshot, membershipsSnapshot] = await Promise.all([
    db.ref(`/meetingRSVPs/${meetingID}`).get(), db.ref(`/clubMemberships/${clubID}`).get(),
  ]);
  const memberships = membershipsSnapshot.val() || {};
  const rows = [];
  const updates = {};
  for (const [uid, value] of Object.entries(responsesSnapshot.val() || {})) {
    const active = value.active !== false && canAccessMeeting(meeting, roleValue(memberships[uid]), uid);
    if (!active && value.active !== false) {
      updates[`${uid}/active`] = false;
      updates[`${uid}/inactiveAt`] = nowSeconds();
      updates[`${uid}/inactiveReason`] = "access-lost";
    }
    rows.push({ uid, status: value.status, active, updatedAt: value.updatedAt || null });
  }
  for (let index = 0; index < rows.length; index += 8) {
    const batch = rows.slice(index, index + 8);
    const names = await Promise.all(batch.map(async ({ uid }) =>
      (await db.ref(`/users/${uid}/userName`).get()).val() || "Student"
    ));
    names.forEach((name, offset) => { rows[index + offset].name = name; });
  }
  if (Object.keys(updates).length) await db.ref(`/meetingRSVPs/${meetingID}`).update(updates);
  return rows.sort((a, b) => a.name.localeCompare(b.name) || a.uid.localeCompare(b.uid));
}

module.exports = {
  acquireLocks, applyMeetingIndexUpdates, canonicalMeeting, clientMeeting, compactCalendarChanges,
  cleanupCompletedMeetingRecords, completeMeetingNotificationJob,
  deleteMeetings, getRSVP, handleDeletedClub,
  listRSVPs, meetingIndexMonths, nextPublicMeeting, occurrenceAssignments, readMeeting, saveMeetings,
  releaseLocks, sameOccurrenceRevisions, setRSVP, syncClubCalendar,
};
