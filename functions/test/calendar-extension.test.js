"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");
const { extendClubCalendar } = require("../lib/meeting-service");
const { apiHandler } = require("../lib/api");

function fixture({ latestChanges = ["cursor"], membership = true } = {}) {
  const meeting = (meetingID, visibility = { mode: "public" }) => ({
    meetingID, clubID: "11", fullDay: true,
    startDate: "2027-10-10", endDateExclusive: "2027-10-11", visibility,
  });
  const data = {
    "/clubMemberships/11/member": membership
      ? { role: "member", email: "member@d214.org" } : null,
    "/clubCalendars/11/months/2027-10": {
      cached: 1, fresh: 1, leadersOnly: 1,
    },
    "/clubMeetings/11/cached": meeting("cached"),
    "/clubMeetings/11/fresh": meeting("fresh"),
    "/clubMeetings/11/leadersOnly": meeting("leadersOnly", { mode: "leaders" }),
  };
  const reads = [];
  let cursorReads = 0;
  const database = {
    ref(path) {
      return {
        async get() {
          reads.push(path);
          if (path === "/clubCalendars/11/latestChange") {
            const cursor = latestChanges[Math.min(cursorReads, latestChanges.length - 1)];
            cursorReads += 1;
            return { val: () => cursor };
          }
          return { val: () => data[path] ?? null };
        },
      };
    },
  };
  return { admin: { database: () => database }, reads };
}

const request = {
  clubID: "11", start: "2027-10-01", end: "2027-11-01",
  after: "cursor", knownMeetingIDs: ["cached"],
};
const member = { uid: "member", email: "member@d214.org", email_verified: true };

test("extension reads only uncached meeting bodies and respects visibility", async () => {
  const { admin, reads } = fixture();
  const result = await extendClubCalendar(admin, member, request);
  assert.deepEqual(result.meetings.map((meeting) => meeting.meetingID), ["fresh"]);
  assert.equal(result.latestChange, "cursor");
  assert.equal(reads.includes("/clubMeetings/11/cached"), false);
  assert.equal(reads.includes("/clubMeetings/11/fresh"), true);
  assert.equal(reads.includes("/clubMeetings/11/leadersOnly"), true);
});

test("extension allows admins to see leader-only meetings", async () => {
  const { admin } = fixture({ membership: false });
  const result = await extendClubCalendar(admin, {
    uid: "admin", phsSuperAdmin: true,
  }, request);
  assert.deepEqual(result.meetings.map((meeting) => meeting.meetingID).sort(),
    ["fresh", "leadersOnly"]);
});

test("extension reads no meeting bodies when the entering month is fully cached", async () => {
  const { admin, reads } = fixture();
  const result = await extendClubCalendar(admin, member, {
    ...request, knownMeetingIDs: ["cached", "fresh", "leadersOnly"],
  });
  assert.deepEqual(result.meetings, []);
  assert.equal(reads.some((path) => path.startsWith("/clubMeetings/")), false);
});

test("extension rejects missing membership and a cursor that changes during the read", async () => {
  const { admin: denied } = fixture({ membership: false });
  await assert.rejects(extendClubCalendar(denied, member, request), { status: 403 });

  const { admin: changed } = fixture({ latestChanges: ["cursor", "new-cursor"] });
  await assert.rejects(extendClubCalendar(changed, member, request), { status: 409 });
});

test("extension rejects a range spanning more than one month", async () => {
  const { admin } = fixture();
  await assert.rejects(extendClubCalendar(admin, member, {
    ...request, end: "2027-12-01",
  }), { status: 400 });
  await assert.rejects(extendClubCalendar(admin, member, {
    ...request, start: "2027-10-32",
  }), { status: 400 });
});

test("authenticated calendar extension route returns the missing meetings", async () => {
  const { admin } = fixture();
  admin.auth = () => ({ verifyIdToken: async () => member });
  const response = {
    statusCode: 200,
    status(code) { this.statusCode = code; return this; },
    set() { return this; },
    json(value) { this.body = value; return this; },
  };
  await apiHandler(admin)({
    method: "POST", path: "/calendar/extend", body: request,
    get: () => "Bearer test-token",
  }, response);
  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body.meetings.map((meeting) => meeting.meetingID), ["fresh"]);
});
