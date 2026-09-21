"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  canonicalLegacyMeeting, initialCalendarUpdates,
} = require("../lib/legacy-calendar");

test("legacy conversion is strict and creates a v2 schema marker", () => {
  const report = { malformedDates: [], missingRevisionTimestamps: [], unresolvedVisibility: [] };
  const meeting = canonicalLegacyMeeting("robotics", 0, {
    title: "Build Night", startTime: "11-01-2026, 3:00 PM",
    endTime: "11-01-2026, 4:00 PM", visibleByArray: ["member@d214.org"],
  }, new Map([["member@d214.org", "member"]]), report, 100);
  assert.equal(report.malformedDates.length, 0);
  assert.equal(meeting.visibility.uids.member, true);
  const updates = initialCalendarUpdates("robotics", [meeting], 100, "repair-test");
  assert.equal(updates["clubCalendars/robotics/schemaVersion"], 2);
  assert.equal(updates["clubs/robotics/calendarStorageVersion"], 2);
  assert.equal(updates["clubCalendars/robotics/sequence"], 1);
});
