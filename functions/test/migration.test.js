"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  authEmailMapFromExport, buildPlan, offlineDatabase,
} = require("../scripts/migrate-calendar-v2");
const { sha256 } = require("../lib/calendar-core");
const { epochSeconds, newerThan } = require("../scripts/rollback-calendar-v2");

function fakeDatabase(existing = {}) {
  return {
    ref(path) {
      return {
        async get() {
          const value = existing[path];
          return { val: () => value == null ? null : value };
        },
      };
    },
  };
}

const legacyMeeting = {
  title: "Build Night",
  startTime: "09-10-2026, 3:00 PM",
  endTime: "09-10-2026, 4:00 PM",
  fullDay: false,
};

test("offline migration input matches Firebase database and Auth exports", async () => {
  const db = offlineDatabase({
    ".priority": null,
    clubs: {
      robotics: {
        name: "Robotics",
        meetingTimes: { ".value": [legacyMeeting], ".priority": 1 },
      },
    },
  });
  const clubs = (await db.ref("/clubs").get()).val();
  assert.equal(clubs.robotics.meetingTimes.length, 1);
  const authState = authEmailMapFromExport({ users: [
    { localId: "active", email: "ACTIVE@d214.org", emailVerified: true },
    { localId: "student", email: "student@stu.d214.org", emailVerified: true },
    { localId: "legacy", email: "legacy@gmail.com", emailVerified: true },
    { localId: "unsupported", email: "unsupported@prime8.dev", emailVerified: true },
    { localId: "unverified", email: "unverified@d214.org", emailVerified: false },
    { localId: "disabled", email: "disabled@d214.org", emailVerified: true, disabled: true },
  ] });
  assert.equal(authState.emailToUID.get("active@d214.org"), "active");
  assert.equal(authState.emailToUID.get("student@stu.d214.org"), "student");
  assert.equal(authState.emailToUID.get("legacy@gmail.com"), "legacy");
  assert.equal(authState.emailToUID.has("unsupported@prime8.dev"), false);
  assert.equal(authState.emailToUID.has("unverified@d214.org"), false);
  assert.equal(authState.emailToUID.has("disabled@d214.org"), false);
});

test("migration dry-run preserves duplicate occurrences and reruns without conflicts", async () => {
  const clubs = {
    robotics: {
      clubID: "robotics",
      name: "Robotics",
      leaders: ["leader@d214.org"],
      members: ["member@d214.org"],
      pendingMemberRequests: ["pending@d214.org", "later@d214.org"],
      meetingTimes: [legacyMeeting, { ...legacyMeeting }],
      lastUpdated: 100,
    },
  };
  const identities = new Map([
    ["leader@d214.org", "leader"],
    ["member@d214.org", "member"],
    ["pending@d214.org", "pending"],
  ]);
  const first = await buildPlan(fakeDatabase(), clubs, identities);
  const meetingPaths = Object.keys(first.updates).filter((path) => path.startsWith("clubMeetings/"));
  assert.equal(meetingPaths.length, 2);
  assert.notEqual(meetingPaths[0], meetingPaths[1]);
  assert.equal(first.report.joinRequests, 1);
  assert.equal(first.report.unresolvedIdentities.some((value) => value.role === "pending"), true);
  assert.equal(first.updates["clubMemberships/robotics/leader"].calendarCursor, "0000000000000001");
  assert.equal(first.updates["userClubMemberships/leader/robotics"].calendarCursor, "0000000000000001");
  assert.equal(
    first.updates[`internal/unresolvedIdentities/robotics/${sha256("leader@d214.org")}`],
    null
  );
  assert.equal(first.updates["clubs/robotics/calendarStorageVersion"], 2);
  assert.equal(first.updates["clubs/robotics/membershipStorageVersion"], 2);
  assert.equal(first.updates["clubCalendars/robotics/schemaVersion"], 2);
  assert.equal(Object.hasOwn(first.updates, "clubs/robotics"), false);
  assert.equal(Object.keys(first.updates).some((path) =>
    path.includes("meetingTimes") || path.endsWith("/members") || path.endsWith("/leaders")
  ), false);

  const existing = Object.fromEntries(meetingPaths.map((path) => [`/${path}`, first.updates[path]]));
  const rerun = await buildPlan(fakeDatabase(existing), clubs, identities);
  assert.equal(rerun.report.conflicts.length, 0);
  assert.deepEqual(
    Object.keys(rerun.updates).filter((path) => path.startsWith("clubMeetings/")),
    meetingPaths
  );
});

test("migration initializes an empty legacy calendar without deleting readable club fields", async () => {
  const clubs = {
    chess: {
      clubID: "chess", name: "Chess", leaders: ["leader@d214.org"],
      members: ["member@d214.org"], meetingTimes: [], lastUpdated: 100,
    },
  };
  const result = await buildPlan(fakeDatabase(), clubs, new Map([
    ["leader@d214.org", "leader"], ["member@d214.org", "member"],
  ]));
  assert.equal(result.updates["clubCalendars/chess/schemaVersion"], 2);
  assert.equal(result.updates["clubCalendars/chess/sequence"], 0);
  assert.equal(result.updates["clubs/chess/calendarStorageVersion"], 2);
  assert.equal(Object.hasOwn(result.updates, "clubs/chess"), false);
});

test("migration rerun does not rebuild an already-authoritative calendar from its projection", async () => {
  const clubs = {
    robotics: {
      clubID: "robotics", name: "Robotics", leaders: ["leader@d214.org"],
      meetingTimes: [{ ...legacyMeeting, meetingID: "canonical-id", revision: 7 }],
      calendarStorageVersion: 2, lastUpdated: 300,
    },
  };
  const result = await buildPlan(fakeDatabase({
    "/clubCalendars/robotics/schemaVersion": 2,
    "/clubCalendars/robotics/latestChange": "0000000000000007",
    "/clubMeetings/robotics": {
      "canonical-id": { meetingID: "canonical-id" },
      "second-id": { meetingID: "second-id" },
    },
  }), clubs, new Map([["leader@d214.org", "leader"]]));
  assert.equal(Object.keys(result.updates).some((path) => path.startsWith("clubMeetings/")), false);
  assert.equal(result.updates["clubMemberships/robotics/leader"].calendarCursor, "0000000000000007");
  assert.equal(result.updates["internal/migrations/calendar-v2/checkpoints/robotics"].meetingCount, 2);
  assert.equal(result.updates["internal/migrations/calendar-v2/checkpoints/robotics"].adoptedExistingV2, true);
  assert.equal(result.report.conflicts.length, 0);
});

test("migration rerun preserves an existing completion checkpoint", async () => {
  const clubs = { robotics: { clubID: "robotics", name: "Robotics", meetingTimes: [] } };
  const result = await buildPlan(fakeDatabase({
    "/clubCalendars/robotics/schemaVersion": 2,
    "/clubCalendars/robotics/latestChange": "0000000000000007",
    "/internal/migrations/calendar-v2/checkpoints/robotics": {
      complete: true, meetingCount: 12, sourceHash: "original",
    },
  }), clubs, new Map());
  assert.equal(
    Object.hasOwn(result.updates, "internal/migrations/calendar-v2/checkpoints/robotics"),
    false
  );
});

test("migration reports malformed legacy dates without substituting current time", async () => {
  const clubs = {
    malformed: {
      name: "Malformed",
      leaders: ["leader@d214.org"],
      meetingTimes: [{ ...legacyMeeting, startTime: "not-a-date" }],
    },
  };
  const result = await buildPlan(fakeDatabase(), clubs, new Map([["leader@d214.org", "leader"]]));
  assert.equal(result.report.malformedDates.length, 1);
  assert.equal(Object.keys(result.updates).some((path) => path.startsWith("clubMeetings/")), false);
});

test("all-day migration stores dates and ignores irrelevant DST wall-clock gaps", async () => {
  const clubs = {
    allday: {
      name: "All Day",
      leaders: ["leader@d214.org"],
      meetingTimes: [{
        ...legacyMeeting,
        fullDay: true,
        startTime: "03-08-2026, 2:30 AM",
        endTime: "03-09-2026, 2:30 AM",
      }],
    },
  };
  const result = await buildPlan(
    fakeDatabase(), clubs, new Map([["leader@d214.org", "leader"]])
  );
  assert.equal(result.report.malformedDates.length, 0);
  const meeting = Object.entries(result.updates)
    .find(([key]) => key.startsWith("clubMeetings/"))[1];
  assert.equal(meeting.startDate, "2026-03-08");
  assert.equal(meeting.endDateExclusive, "2026-03-10");
  assert.equal(meeting.startUtc, undefined);
});

test("rollback safety compares second and millisecond timestamps consistently", () => {
  const cutoff = 1_789_000_000;
  assert.equal(epochSeconds(1_788_999_999_000), 1_788_999_999);
  assert.equal(newerThan({ updatedAt: 1_788_999_999_000 }, cutoff), false);
  assert.equal(newerThan({ nested: { committedAt: 1_789_000_001_000 } }, cutoff), true);
});
