"use strict";

const { monthKeys } = require("./calendar-core");
const { sha256 } = require("./calendar-core");
const { normalizedEmail, uniqueEmails } = require("./access");

function legacyVisibilityClaimUpdates(updates, meetingID, clubID, emails, emailToUID, timestamp) {
  for (const email of uniqueEmails(emails)) {
    const hash = sha256(email);
    updates[`internal/meetingVisibilityClaims/${hash}/${meetingID}`] = {
      clubID,
      email,
      state: "active",
      lastUID: emailToUID.get(email) || null,
      updatedAt: timestamp,
    };
    updates[`internal/meetingVisibilityClaimsByMeeting/${meetingID}/${hash}`] = true;
  }
}

async function syncMeetingVisibilityClaims(db, updates, {
  meetingID, oldClubID, newClubID, mode, claims, claimsProvided, cancelled, timestamp,
}) {
  const reverse = (await db.ref(`/internal/meetingVisibilityClaimsByMeeting/${meetingID}`).get()).val() || {};
  const oldHashes = Object.keys(reverse);
  const clear = cancelled || mode !== "uids";
  if (!claimsProvided && !clear) {
    if (oldClubID && newClubID && oldClubID !== newClubID) {
      for (const hash of oldHashes) {
        updates[`internal/meetingVisibilityClaims/${hash}/${meetingID}/clubID`] = newClubID;
        updates[`internal/meetingVisibilityClaims/${hash}/${meetingID}/updatedAt`] = timestamp;
      }
    }
    return;
  }

  const desired = clear ? new Map() : new Map((claims || []).map((claim) => [claim.hash, claim]));
  for (const hash of oldHashes) {
    if (desired.has(hash)) continue;
    updates[`internal/meetingVisibilityClaims/${hash}/${meetingID}/state`] = "revoked";
    updates[`internal/meetingVisibilityClaims/${hash}/${meetingID}/lastUID`] = null;
    updates[`internal/meetingVisibilityClaims/${hash}/${meetingID}/updatedAt`] = timestamp;
    updates[`internal/meetingVisibilityClaimsByMeeting/${meetingID}/${hash}`] = null;
  }
  for (const claim of desired.values()) {
    updates[`internal/meetingVisibilityClaims/${claim.hash}/${meetingID}`] = {
      clubID: newClubID,
      email: claim.email,
      state: "active",
      lastUID: claim.uid || null,
      updatedAt: timestamp,
    };
    updates[`internal/meetingVisibilityClaimsByMeeting/${meetingID}/${claim.hash}`] = true;
  }
}

function changedMeeting(oldMeeting, uids, timestamp) {
  return {
    ...oldMeeting,
    visibility: { mode: "uids", uids },
    updatedAt: timestamp,
    revision: Number(oldMeeting.revision || 0) + 1,
  };
}

function addChange(changesByClub, meeting) {
  if (!changesByClub.has(meeting.clubID)) changesByClub.set(meeting.clubID, []);
  changesByClub.get(meeting.clubID).push(meeting);
}

async function restoreIdentityVisibility(db, updates, hash, uid, email, claims, timestamp) {
  const changesByClub = new Map();
  for (const [meetingID, claim] of Object.entries(claims || {})) {
    if (claim?.state !== "active" || normalizedEmail(claim.email) !== email) continue;
    const clubID = String(claim.clubID || "");
    if (!clubID) continue;
    const meeting = (await db.ref(`/clubMeetings/${clubID}/${meetingID}`).get()).val();
    if (!meeting || meeting.cancelled || meeting.visibility?.mode !== "uids") continue;
    const uids = { ...(meeting.visibility.uids || {}) };
    if (claim.lastUID && claim.lastUID !== uid) delete uids[claim.lastUID];
    if (uids[uid] !== true || claim.lastUID !== uid) {
      uids[uid] = true;
      const next = changedMeeting({ ...meeting, meetingID, clubID }, uids, timestamp);
      updates[`clubMeetings/${clubID}/${meetingID}`] = next;
      addChange(changesByClub, next);
    }
    updates[`internal/meetingVisibilityClaims/${hash}/${meetingID}/lastUID`] = uid;
    updates[`internal/meetingVisibilityClaims/${hash}/${meetingID}/updatedAt`] = timestamp;
  }
  return changesByClub;
}

async function removeIdentityVisibility(db, updates, hash, uid, claims, timestamp) {
  const changesByClub = new Map();
  for (const [meetingID, claim] of Object.entries(claims || {})) {
    if (claim?.lastUID !== uid) continue;
    const clubID = String(claim.clubID || "");
    const meeting = clubID
      ? (await db.ref(`/clubMeetings/${clubID}/${meetingID}`).get()).val() : null;
    if (meeting && !meeting.cancelled && meeting.visibility?.mode === "uids" && meeting.visibility.uids?.[uid]) {
      const uids = { ...(meeting.visibility.uids || {}) };
      delete uids[uid];
      const next = changedMeeting({ ...meeting, meetingID, clubID }, uids, timestamp);
      updates[`clubMeetings/${clubID}/${meetingID}`] = next;
      addChange(changesByClub, next);
    }
    updates[`internal/meetingVisibilityClaims/${hash}/${meetingID}/lastUID`] = null;
    updates[`internal/meetingVisibilityClaims/${hash}/${meetingID}/updatedAt`] = timestamp;
  }
  return changesByClub;
}

function mergeChanges(target, source) {
  for (const [clubID, meetings] of source.entries()) {
    if (!target.has(clubID)) target.set(clubID, []);
    target.get(clubID).push(...meetings);
  }
}

async function publishVisibilityChanges(db, updates, changesByClub, operationPrefix, timestamp) {
  for (const [clubID, values] of changesByClub.entries()) {
    const meetings = Array.from(new Map(values.map((meeting) => [meeting.meetingID, meeting])).values());
    if (!meetings.length) continue;
    const sequence = Number((await db.ref(`/clubCalendars/${clubID}/sequence`).get()).val() || 0) + 1;
    const cursor = String(sequence).padStart(16, "0");
    for (const meeting of meetings) {
      for (const month of monthKeys(meeting.startDate, meeting.endDateExclusive)) {
        updates[`clubCalendars/${clubID}/months/${month}/${meeting.meetingID}`] = meeting.revision;
      }
    }
    updates[`clubCalendars/${clubID}/sequence`] = sequence;
    updates[`clubCalendars/${clubID}/latestChange`] = cursor;
    updates[`clubCalendars/${clubID}/updatedAt`] = timestamp;
    updates[`clubCalendars/${clubID}/changes/${cursor}`] = {
      operationID: `${operationPrefix}-${cursor}`,
      committedAt: timestamp,
      items: meetings.map((meeting) => ({
        meetingID: meeting.meetingID,
        operation: "upsert",
        meetingRevision: meeting.revision,
        startDate: meeting.startDate,
        endDateExclusive: meeting.endDateExclusive,
        updatedAt: meeting.updatedAt,
      })),
    };
  }
}

module.exports = {
  legacyVisibilityClaimUpdates,
  mergeChanges,
  publishVisibilityChanges,
  removeIdentityVisibility,
  restoreIdentityVisibility,
  syncMeetingVisibilityClaims,
};
