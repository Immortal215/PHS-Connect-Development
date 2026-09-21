"use strict";

const crypto = require("crypto");
const { isEligibleAuthUser } = require("./access");
const {
  canAccessMeeting,
  dependencyFingerprint,
  fixedFeedWindow,
  monthKeys,
  overlapsWindow,
  sha256,
} = require("./calendar-core");
const { FEED_LOCK_SECONDS } = require("./constants");
const { generateCalendar } = require("./ical");

function roleValue(value) {
  return typeof value === "string" ? value : value?.role;
}

async function readClubDependencies(db, clubIDs) {
  const pairs = await Promise.all(clubIDs.map(async (clubID) => {
    const [cursor, name] = await Promise.all([
      db.ref(`/clubCalendars/${clubID}/latestChange`).get(),
      db.ref(`/clubs/${clubID}/name`).get(),
    ]);
    return [clubID, {
      cursor: cursor.val() || "",
      name: name.val() || "Club Meeting",
    }];
  }));
  return Object.fromEntries(pairs);
}

async function readDependencyState(db, uid, dayKey, verifiedEmail) {
  const membershipsSnapshot = await db.ref(`/userClubMemberships/${uid}`).get();
  const memberships = membershipsSnapshot.val() || {};
  const normalizedEmail = String(verifiedEmail || "").trim().toLowerCase();
  const clubIDs = Object.keys(memberships).filter((clubID) => {
    const membership = memberships[clubID];
    return ["member", "leader"].includes(roleValue(membership)) &&
      String(membership?.email || "").trim().toLowerCase() === normalizedEmail;
  });
  const authorizedMemberships = Object.fromEntries(clubIDs.map((id) => [id, memberships[id]]));
  const dependencies = await readClubDependencies(db, clubIDs);
  const clubCursors = Object.fromEntries(clubIDs.map((id) => [id, dependencies[id].cursor]));
  const fingerprint = dependencyFingerprint({
    memberships: authorizedMemberships,
    clubCursors,
    clubMetadata: dependencies,
    dayKey,
  });
  return { memberships: authorizedMemberships, clubIDs, dependencies, fingerprint };
}

async function loadIndexedMeetings(db, clubIDs, window) {
  const keys = monthKeys(window.startDate, window.endDateExclusive);
  const meetingKeys = new Map();
  await Promise.all(clubIDs.flatMap((clubID) => keys.map(async (monthKey) => {
    const snapshot = await db.ref(`/clubCalendars/${clubID}/months/${monthKey}`).get();
    for (const meetingID of Object.keys(snapshot.val() || {})) {
      meetingKeys.set(`${clubID}\u0000${meetingID}`, { clubID, meetingID });
    }
  })));

  const ids = Array.from(meetingKeys.values());
  const meetings = [];
  for (let index = 0; index < ids.length; index += 25) {
    const chunk = ids.slice(index, index + 25);
    const values = await Promise.all(chunk.map(async ({ clubID, meetingID }) => {
      const snapshot = await db.ref(`/clubMeetings/${clubID}/${meetingID}`).get();
      const value = snapshot.val();
      if (!value) throw new Error(`Calendar index points to missing meeting ${meetingID}.`);
      return { ...value, meetingID: value.meetingID || meetingID };
    }));
    meetings.push(...values);
  }
  return meetings.filter((meeting) => overlapsWindow(meeting, window));
}

async function buildFeed(db, uid, dependencyState, window) {
  const allMeetings = await loadIndexedMeetings(db, dependencyState.clubIDs, window);
  const meetings = allMeetings.filter((meeting) => canAccessMeeting(
    meeting,
    roleValue(dependencyState.memberships[meeting.clubID]),
    uid
  ));
  meetings.sort((first, second) => {
    const firstValue = first.fullDay ? first.startDate : Number(first.startUtc);
    const secondValue = second.fullDay ? second.startDate : Number(second.startUtc);
    return firstValue < secondValue ? -1 : firstValue > secondValue ? 1 : 0;
  });
  const clubNames = Object.fromEntries(dependencyState.clubIDs.map((clubID) => [
    clubID,
    dependencyState.dependencies[clubID].name,
  ]));
  const body = generateCalendar({ meetings, clubNames });
  const builtAt = Math.floor(Date.now() / 1000);
  return {
    body,
    builtAt,
    etag: sha256(body),
    fingerprint: dependencyState.fingerprint,
    meetingCount: meetings.length,
    window,
  };
}

async function acquireLock(db, uid) {
  const owner = crypto.randomUUID();
  const now = Math.floor(Date.now() / 1000);
  const ref = db.ref(`/internal/calendarBuildLocks/${uid}`);
  const result = await ref.transaction((current) => {
    if (current?.expiresAt > now) return;
    return { owner, expiresAt: now + FEED_LOCK_SECONDS };
  }, undefined, false);
  return {
    acquired: result.committed && result.snapshot.val()?.owner === owner,
    owner,
    ref,
  };
}

async function releaseLock(lock) {
  if (!lock.acquired) return;
  await lock.ref.transaction((current) => current?.owner === lock.owner ? null : current, undefined, false);
}

async function resolveToken(admin, rawToken) {
  const db = admin.database();
  if (!rawToken || rawToken.length < 32 || rawToken.length > 256) return null;
  const tokenHash = sha256(rawToken);
  const tokenSnapshot = await db.ref(`/calendarTokens/${tokenHash}`).get();
  const token = tokenSnapshot.val();
  if (!token?.uid || token.valid !== true) return null;
  const [stateHash, revoked, generation] = await Promise.all([
    db.ref(`/calendarSubscriptions/${token.uid}/tokenHash`).get(),
    db.ref(`/calendarSubscriptions/${token.uid}/revoked`).get(),
    db.ref(`/calendarSubscriptions/${token.uid}/generation`).get(),
  ]);
  if (revoked.val() === true || stateHash.val() !== tokenHash ||
      Number(generation.val() || 0) !== Number(token.generation || 0)) return null;
  let user;
  try {
    user = await admin.auth().getUser(token.uid);
  } catch (error) {
    if (error?.code === "auth/user-not-found") return null;
    throw error;
  }
  const email = String(user.email || "").trim().toLowerCase();
  if (!isEligibleAuthUser(user)) return null;
  return { uid: token.uid, tokenHash, email };
}

async function getCalendarResponse(admin, rawToken, requestHeaders = {}) {
  const db = admin.database();
  const resolved = await resolveToken(admin, rawToken);
  if (!resolved) return { status: 404 };

  const window = fixedFeedWindow();
  const cacheRef = db.ref(`/calendarSubscriptions/${resolved.uid}/cache/${window.dayKey}`);
  const dependencyState = await readDependencyState(db, resolved.uid, window.dayKey, resolved.email);
  const cache = (await cacheRef.child("meta").get()).val();

  if (cache?.etag && cache.fingerprint === dependencyState.fingerprint) {
    if (requestHeaders["if-none-match"]?.replace(/^W\//, "").replaceAll('"', "") === cache.etag) {
      return { status: 304, cacheHit: true, cache };
    }
    const body = (await cacheRef.child("body").get()).val();
    if (body) return { status: 200, cacheHit: true, cache: { ...cache, body } };
  }

  const lock = await acquireLock(db, resolved.uid);
  if (!lock.acquired) return { status: 503, retryAfter: 5 };
  try {
    const secondCache = (await cacheRef.child("meta").get()).val();
    if (secondCache?.etag && secondCache.fingerprint === dependencyState.fingerprint) {
      const body = (await cacheRef.child("body").get()).val();
      if (body) return { status: 200, cacheHit: true, cache: { ...secondCache, body } };
    }
    const rebuilt = await buildFeed(db, resolved.uid, dependencyState, window);
    const finalDependencyState = await readDependencyState(db, resolved.uid, window.dayKey, resolved.email);
    if (finalDependencyState.fingerprint !== dependencyState.fingerprint) {
      throw new Error("Calendar dependencies changed during feed generation.");
    }
    const { body, ...meta } = rebuilt;
    await cacheRef.set({ meta, body });
    const cacheParent = db.ref(`/calendarSubscriptions/${resolved.uid}/cache`);
    const cacheKeys = Object.keys((await cacheParent.get()).val() || {}).sort().reverse();
    if (cacheKeys.length > 3) {
      const removals = Object.fromEntries(cacheKeys.slice(3).map((key) => [key, null]));
      await cacheParent.update(removals);
    }
    return { status: 200, cacheHit: false, cache: rebuilt };
  } finally {
    await releaseLock(lock);
  }
}

module.exports = {
  buildFeed,
  getCalendarResponse,
  loadIndexedMeetings,
  readDependencyState,
  readClubDependencies,
  resolveToken,
  roleValue,
};
