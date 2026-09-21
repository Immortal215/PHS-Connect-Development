"use strict";

const assert = require("node:assert/strict");
const fs = require("fs");
const path = require("path");
const test = require("node:test");

const rulesText = fs.readFileSync(
  path.resolve(__dirname, "../../database.rules.json"), "utf8"
);
const rules = JSON.parse(rulesText).rules;

test("production queries have declared indexes", () => {
  assert.ok(rules.clubs[".indexOn"].includes("lastUpdated"));
  assert.ok(rules.clubs[".indexOn"].includes("name"));
  assert.ok(rules.clubMeetings.$club_id[".indexOn"].includes("seriesID"));
  assert.ok(rules.chats.$chat_id.messages[".indexOn"].includes("threadName"));
  assert.ok(rules.global[".indexOn"].includes("lastUpdated"));
  assert.ok(rules.internal.notificationRetryJobs[".indexOn"].includes("nextAttempt"));
});

test("new private trees and legacy authorization bypasses are client-denied", () => {
  for (const key of [
    "clubJoinRequests", "clubCalendars", "meetingRSVPs", "userRSVPIndex",
    "calendarSubscriptions", "calendarTokens", "notificationDevices", "internal",
  ]) {
    assert.equal(rules[key][".read"], false, `${key} must not be readable`);
    assert.equal(rules[key][".write"], false, `${key} must not be writable`);
  }
  for (const key of [
    "meetingTimes", "members", "leaders", "membersUIDs", "leadersUIDs",
    "pendingMemberRequests",
  ]) assert.equal(rules.clubs.$club_id[key][".write"], false);
  assert.equal(rules.users.$user_id[".write"], false);
  assert.equal(rules.users.$user_id.fcmToken[".write"], false);
  assert.match(rules.users.$user_id.userID[".write"], /auth\.uid === \$user_id/);
  assert.match(rules.clubs.$club_id.chatEnabled[".write"], /role.*leader/);
  assert.match(rules.clubs.$club_id.chatEnabled[".write"], /sharul\.shah2008@gmail\.com/);
  assert.match(rules.clubs.$club_id.locationInSchoolCoordinates[".write"], /role.*leader/);
  assert.match(rules.clubs.$club_id.locationInSchoolCoordinates[".write"], /sharul\.shah2008@gmail\.com/);
});

test("database rules avoid unsupported RTDB snapshot methods", () => {
  assert.equal(rulesText.includes("numChildren("), false);
});

test("deployed runtime has no legacy conversion or roster projection path", () => {
  const api = fs.readFileSync(path.resolve(__dirname, "../lib/api.js"), "utf8");
  const meetings = fs.readFileSync(
    path.resolve(__dirname, "../lib/meeting-service.js"), "utf8"
  );
  const memberships = fs.readFileSync(
    path.resolve(__dirname, "../lib/membership-service.js"), "utf8"
  );

  assert.equal(api.includes("clubs/ensure-calendar-v2"), false);
  assert.equal(meetings.includes("ensureClubCalendarV2"), false);
  assert.equal(memberships.includes("appendLegacyRosterProjection"), false);
  assert.equal(memberships.includes("legacyMembershipUpdates"), false);
});
