#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { monthKeys, sha256 } = require("../lib/calendar-core");
const { createAdminServices } = require("../lib/firebase-admin-services");
const { legacyMeetingID } = require("../lib/legacy-calendar");
const { offlineDatabase } = require("./migrate-calendar-v2");

function parseArguments(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value.startsWith("--")) result[value.slice(2)] = argv[++index];
  }
  return result;
}

function object(value) { return value && typeof value === "object" ? value : {}; }
function role(value) { return typeof value === "string" ? value : value?.role; }

function validateState({
  clubs, calendars, meetings, clubMemberships, userClubMemberships,
  checkpoints, repairs, unresolvedIdentities, visibilityClaims,
  visibilityClaimsByMeeting, visibilityClaimsComplete,
}) {
  const report = {
    clubCount: Object.keys(clubs).length,
    canonicalMeetingCount: 0,
    frozenLegacyMeetingCount: 0,
    unresolvedIdentityCount: 0,
    visibilityClaimCount: Object.values(visibilityClaims)
      .reduce((total, values) => total + Object.keys(object(values)).length, 0),
    missingSchema: [],
    missingPublicMarker: [],
    missingMembershipMarker: [],
    missingRosterIdentityCoverage: [],
    missingAuditEvidence: [],
    missingMeetingIndexEntries: [],
    reciprocalMembershipErrors: [],
    missingVisibilityClaimEvidence: [],
    missingVisibilityClaims: [],
    legacyFieldsPresent: {},
  };
  for (const [clubID, clubValue] of Object.entries(clubs)) {
    const club = object(clubValue);
    const calendar = object(calendars[clubID]);
    const clubMeetings = object(meetings[clubID]);
    const checkpoint = object(checkpoints[clubID]);
    const repair = object(repairs[clubID]);
    if (Number(calendar.schemaVersion || 0) < 2) report.missingSchema.push(clubID);
    if (Number(club.calendarStorageVersion || 0) < 2) report.missingPublicMarker.push(clubID);
    if (Number(club.membershipStorageVersion || 0) < 2) report.missingMembershipMarker.push(clubID);
    if (checkpoint.complete !== true && repair.complete !== true) report.missingAuditEvidence.push(clubID);
    const legacy = Array.isArray(club.meetingTimes)
      ? club.meetingTimes.filter(Boolean) : Object.values(object(club.meetingTimes)).filter(Boolean);
    if (visibilityClaimsComplete.complete !== true && Number(repair.visibilityClaimsVersion || 0) < 1 &&
        Number(checkpoint.visibilityClaimsVersion || 0) < 1) {
      report.missingVisibilityClaimEvidence.push(clubID);
    }
    legacy.forEach((legacyMeeting, index) => {
      const meetingID = legacyMeeting.meetingID || legacyMeetingID(clubID, index, legacyMeeting);
      const emails = Array.from(new Set((Array.isArray(legacyMeeting.visibleByArray)
        ? legacyMeeting.visibleByArray : Object.values(object(legacyMeeting.visibleByArray)))
        .map((email) => String(email || "").trim().toLowerCase()).filter(Boolean)));
      for (const email of emails) {
        const hash = sha256(email);
        const forward = object(object(visibilityClaims[hash])[meetingID]);
        const reverse = object(visibilityClaimsByMeeting[meetingID])[hash];
        if (forward.state !== "active" || forward.clubID !== clubID || forward.email !== email || reverse !== true) {
          report.missingVisibilityClaims.push({ clubID, meetingID, emailHash: hash });
        }
      }
    });
    report.frozenLegacyMeetingCount += legacy.length;
    report.legacyFieldsPresent[clubID] = {
      meetingTimes: Object.hasOwn(club, "meetingTimes"),
      leaders: Object.hasOwn(club, "leaders"),
      members: Object.hasOwn(club, "members"),
      pendingMemberRequests: Object.hasOwn(club, "pendingMemberRequests"),
    };
    const indexedRoster = new Set();
    for (const value of Object.values(object(clubMemberships[clubID]))) {
      const email = String(value?.email || "").trim().toLowerCase();
      if (email && ["leader", "member"].includes(role(value))) indexedRoster.add(`${role(value)}:${email}`);
    }
    for (const value of Object.values(object(unresolvedIdentities[clubID]))) {
      const email = String(value?.email || "").trim().toLowerCase();
      if (email && ["leader", "member"].includes(value?.role)) indexedRoster.add(`${value.role}:${email}`);
    }
    const legacyLeaderEmails = new Set(
      (Array.isArray(club.leaders) ? club.leaders : Object.values(object(club.leaders)))
        .map((value) => String(value || "").trim().toLowerCase()).filter(Boolean)
    );
    for (const rosterRole of ["leader", "member"]) {
      const source = rosterRole === "leader" ? club.leaders : club.members;
      const emails = Array.isArray(source) ? source : Object.values(object(source));
      for (const value of emails) {
        const email = String(value || "").trim().toLowerCase();
        if (rosterRole === "member" && legacyLeaderEmails.has(email)) continue;
        if (email && !indexedRoster.has(`${rosterRole}:${email}`)) {
          report.missingRosterIdentityCoverage.push({ clubID, role: rosterRole, email });
        }
      }
    }
    for (const [meetingID, meetingValue] of Object.entries(clubMeetings)) {
      const meeting = object(meetingValue);
      report.canonicalMeetingCount += 1;
      if (!meeting.startDate || !meeting.endDateExclusive) {
        report.missingMeetingIndexEntries.push({ clubID, meetingID, reason: "missing-date-range" });
        continue;
      }
      let indexedMonths;
      try {
        indexedMonths = monthKeys(meeting.startDate, meeting.endDateExclusive);
      } catch {
        report.missingMeetingIndexEntries.push({ clubID, meetingID, reason: "invalid-date-range" });
        continue;
      }
      for (const month of indexedMonths) {
        const indexedRevision = object(object(calendar.months)[month])[meetingID];
        if (Number(indexedRevision || 0) !== Number(meeting.revision || 0)) {
          report.missingMeetingIndexEntries.push({
            clubID, meetingID, month, expectedRevision: meeting.revision || 0,
            indexedRevision: indexedRevision || null,
          });
        }
      }
    }
    for (const [uid, membership] of Object.entries(object(clubMemberships[clubID]))) {
      const reverse = object(object(userClubMemberships[uid])[clubID]);
      if (role(reverse) !== role(membership)) {
        report.reciprocalMembershipErrors.push({
          clubID, uid, clubRole: role(membership) || null, userRole: role(reverse) || null,
        });
      }
    }
  }
  report.unresolvedIdentityCount = Object.values(unresolvedIdentities)
    .reduce((total, values) => total + Object.keys(object(values)).length, 0);
  for (const [uid, memberships] of Object.entries(userClubMemberships)) {
    for (const [clubID, membership] of Object.entries(object(memberships))) {
      if (role(membership) === "pending") continue;
      const forward = object(object(clubMemberships[clubID])[uid]);
      if (role(forward) !== role(membership) && !report.reciprocalMembershipErrors.some(
        (item) => item.clubID === clubID && item.uid === uid
      )) {
        report.reciprocalMembershipErrors.push({
          clubID, uid, clubRole: role(forward) || null, userRole: role(membership) || null,
        });
      }
    }
  }
  report.dataReady = [
    report.missingSchema,
    report.missingPublicMarker,
    report.missingMembershipMarker,
    report.missingRosterIdentityCoverage,
    report.missingAuditEvidence,
    report.missingMeetingIndexEntries,
    report.reciprocalMembershipErrors,
    report.missingVisibilityClaimEvidence,
    report.missingVisibilityClaims,
  ].every((values) => values.length === 0);
  return report;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const projectID = options.project;
  if (!projectID) throw new Error("Pass --project with the exact Firebase project ID.");
  let db;
  if (options["database-export"]) {
    const exported = JSON.parse(fs.readFileSync(path.resolve(options["database-export"]), "utf8"));
    db = offlineDatabase(exported);
  } else {
    const admin = createAdminServices({ projectId: projectID, databaseURL: options["database-url"] });
    db = admin.database();
  }
  const paths = [
    "clubs", "clubCalendars", "clubMeetings", "clubMemberships", "userClubMemberships",
    "internal/migrations/calendar-v2/checkpoints", "internal/legacyCalendarRepairs",
    "internal/unresolvedIdentities", "internal/meetingVisibilityClaims",
    "internal/meetingVisibilityClaimsByMeeting", "internal/migrations/calendar-v2/visibilityClaims",
  ];
  const values = await Promise.all(paths.map(async (path) =>
    (await db.ref(`/${path}`).get()).val() || {}
  ));
  const report = validateState({
    clubs: values[0], calendars: values[1], meetings: values[2],
    clubMemberships: values[3], userClubMemberships: values[4],
    checkpoints: values[5], repairs: values[6], unresolvedIdentities: values[7],
    visibilityClaims: values[8], visibilityClaimsByMeeting: values[9],
    visibilityClaimsComplete: values[10],
  });
  console.log(JSON.stringify({ projectID, checkedAt: new Date().toISOString(), report }, null, 2));
  if (!report.dataReady) process.exitCode = 2;
}

if (require.main === module) main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});

module.exports = { validateState };
