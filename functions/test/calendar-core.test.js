"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  canAccessMeeting, dependencyFingerprint, fixedFeedWindow, monthKeys, overlapsWindow,
  rsvpCutoffEpoch, zonedMidnightEpoch,
} = require("../lib/calendar-core");
const {
  canonicalMeeting, occurrenceAssignments, sameOccurrenceRevisions,
} = require("../lib/meeting-service");
const { generateCalendar } = require("../lib/ical");
const { meetingID, strictLegacyDate } = require("../scripts/migrate-calendar-v2");

test("feed window uses Chicago day, 30-day lookback, and one calendar year", () => {
  assert.deepEqual(fixedFeedWindow(new Date("2024-02-29T18:00:00Z")), {
    dayKey: "2024-02-29", startDate: "2024-01-30", endDateExclusive: "2025-03-01",
  });
});

test("month indexes honor exclusive ends and multiday overlap", () => {
  assert.deepEqual(monthKeys("2026-01-31", "2026-02-01"), ["2026-01"]);
  assert.deepEqual(monthKeys("2026-01-31", "2026-02-02"), ["2026-01", "2026-02"]);
  assert.equal(overlapsWindow({ fullDay: true, startDate: "2026-01-30", endDateExclusive: "2026-02-03" }, {
    startDate: "2026-02-01", endDateExclusive: "2026-02-02",
  }), true);
});

test("Chicago all-day RSVP cutoff follows midnight across DST", () => {
  assert.equal(new Date(zonedMidnightEpoch("2026-03-08") * 1000).toISOString(), "2026-03-08T06:00:00.000Z");
  assert.equal(new Date(zonedMidnightEpoch("2026-03-09") * 1000).toISOString(), "2026-03-09T05:00:00.000Z");
  assert.equal(rsvpCutoffEpoch({ fullDay: true, startDate: "2026-11-02" }), zonedMidnightEpoch("2026-11-02"));
});

test("visibility grants leaders and eligible members only", () => {
  const meeting = { visibility: { mode: "uids", uids: { selected: true } } };
  assert.equal(canAccessMeeting(meeting, "leader", "leader"), true);
  assert.equal(canAccessMeeting(meeting, "member", "selected"), true);
  assert.equal(canAccessMeeting(meeting, "member", "other"), false);
  assert.equal(canAccessMeeting(meeting, null, "selected"), false);
});

test("ordinary meeting edits retain ID and advance revision", () => {
  const previous = {
    meetingID: "meeting-1", clubID: "club", title: "Old", fullDay: false,
    startUtc: 1788876000, endUtc: 1788879600, createdAt: 10, revision: 7,
  };
  const updated = canonicalMeeting({ ...previous, title: "New", startUtc: 1788879600, endUtc: 1788883200 }, {
    meetingID: previous.meetingID, previous, now: 20,
  });
  assert.equal(updated.meetingID, "meeting-1");
  assert.equal(updated.revision, 8);
  assert.equal(updated.createdAt, 10);
});

test("this-and-future edits reuse surviving occurrence IDs in chronological order", () => {
  let generated = 0;
  const existing = [
    { meetingID: "one" }, { meetingID: "two" }, { meetingID: "three" },
  ];
  const sameLength = occurrenceAssignments(existing, [{}, {}, {}], () => `new-${++generated}`);
  assert.deepEqual(sameLength.map((value) => value.meetingID), ["one", "two", "three"]);
  const expanded = occurrenceAssignments(existing, [{}, {}, {}, {}], () => `new-${++generated}`);
  assert.deepEqual(expanded.map((value) => value.meetingID), ["one", "two", "three", "new-1"]);
  const shortened = occurrenceAssignments(existing, [{}], () => `new-${++generated}`);
  assert.deepEqual(shortened.map((value) => value.meetingID), ["one"]);
  assert.deepEqual(existing.slice(shortened.length).map((value) => value.meetingID), ["two", "three"]);
});

test("series concurrency checks detect added, removed, or revised occurrences", () => {
  const base = [{ meetingID: "one", revision: 1 }, { meetingID: "two", revision: 2 }];
  assert.equal(sameOccurrenceRevisions(base, base.map((value) => ({ ...value }))), true);
  assert.equal(sameOccurrenceRevisions(base, [...base, { meetingID: "three", revision: 1 }]), false);
  assert.equal(sameOccurrenceRevisions(base, [{ ...base[0], revision: 2 }, base[1]]), false);
  assert.equal(sameOccurrenceRevisions(base, [base[1], base[0]]), false);
});

test("feed dependency fingerprint changes only for rendered access dependencies", () => {
  const base = {
    memberships: { club: { role: "member", accessRevision: 1 } },
    clubCursors: { club: "0001" },
    clubMetadata: { club: { name: "Robotics", unrelated: 1 } },
    dayKey: "2026-09-11",
  };
  assert.equal(
    dependencyFingerprint(base),
    dependencyFingerprint({
      ...base,
      memberships: { club: { role: "member", accessRevision: 999 } },
      clubMetadata: { club: { name: "Robotics", unrelated: 999 } },
    })
  );
  assert.notEqual(dependencyFingerprint(base), dependencyFingerprint({ ...base, clubCursors: { club: "0002" } }));
  assert.notEqual(dependencyFingerprint(base), dependencyFingerprint({ ...base, memberships: { club: { role: "leader" } } }));
  assert.notEqual(dependencyFingerprint(base), dependencyFingerprint({ ...base, clubMetadata: { club: { name: "Robotics Club" } } }));
  assert.notEqual(dependencyFingerprint(base), dependencyFingerprint({ ...base, dayKey: "2026-09-12" }));
});

test("iCalendar has stable identity, revisions, all-day exclusive end, cancellation, and folded UTF-8", () => {
  const body = generateCalendar({
    clubNames: { club: "Science" },
    meetings: [{
      meetingID: "meeting-1", clubID: "club", revision: 4, createdAt: 100,
      updatedAt: 200, title: `A very long ${"🧪".repeat(40)}`,
      description: "one,two;three\nfour", location: "Lab", fullDay: true,
      startDate: "2026-10-10", endDateExclusive: "2026-10-12", cancelled: true,
    }],
  });
  assert.match(body, /UID:meeting-1@phs-connect\r\n/);
  assert.match(body, /SEQUENCE:4\r\n/);
  assert.match(body, /DTSTART;VALUE=DATE:20261010/);
  assert.match(body, /DTEND;VALUE=DATE:20261012/);
  assert.match(body, /STATUS:CANCELLED/);
  assert.match(body, /DESCRIPTION:one\\,two\\;three\\nfour/);
  for (const line of body.split("\r\n")) assert.ok(Buffer.byteLength(line, "utf8") <= 75);
});

test("iCalendar revision metadata remains deterministic when legacy timestamps are absent", () => {
  const meeting = {
    meetingID: "legacy", clubID: "club", revision: 1, title: "Legacy",
    fullDay: false, startUtc: 1_789_000_000, endUtc: 1_789_003_600,
    timeZone: "America/Chicago",
  };
  const first = generateCalendar({ meetings: [meeting], clubNames: { club: "Club" } });
  const second = generateCalendar({ meetings: [meeting], clubNames: { club: "Club" } });
  assert.equal(first, second);
  assert.match(first, /DTSTAMP:20260910T002640Z/);
});

test("migration IDs preserve duplicate legacy occurrences by source position", () => {
  const legacy = { title: "Same", startTime: "09-10-2026, 3:00 PM", endTime: "09-10-2026, 4:00 PM" };
  assert.notEqual(meetingID("club", 0, legacy), meetingID("club", 1, legacy));
  assert.equal(meetingID("club", 0, legacy), meetingID("club", 0, legacy));
});

test("legacy parser rejects malformed, nonexistent, and ambiguous Chicago times", () => {
  assert.equal(strictLegacyDate("garbage").error, "invalid-format");
  assert.equal(strictLegacyDate("03-08-2026, 2:30 AM").error, "nonexistent-local-time");
  assert.equal(strictLegacyDate("11-01-2026, 1:30 AM").error, "ambiguous-local-time");
  assert.equal(strictLegacyDate("09-10-2026, 3:15 PM").epoch, 1789071300);
});
