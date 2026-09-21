"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { fixedFeedWindow, sha256 } = require("../lib/calendar-core");
const { getCalendarResponse, readDependencyState } = require("../lib/calendar-service");

function at(root, path) {
  return path.split("/").filter(Boolean).reduce((value, key) => value?.[key], root);
}

function fakeAdmin(data, reads) {
  const db = {
    ref(path) {
      return {
        child(key) { return db.ref(`${path}/${key}`); },
        async get() {
          reads.push(path);
          const value = at(data, path);
          return { val: () => value, exists: () => value != null };
        },
      };
    },
  };
  return {
    database: () => db,
    auth: () => ({
      getUser: async (uid) => ({
        uid, email: "student@d214.org", emailVerified: true, disabled: false,
      }),
    }),
  };
}

test("unchanged warm calendar feed validates access without reading meeting bodies", async () => {
  const rawToken = "a".repeat(48);
  const tokenHash = sha256(rawToken);
  const window = fixedFeedWindow();
  const data = {
    calendarTokens: { [tokenHash]: { uid: "student", generation: 2, valid: true } },
    calendarSubscriptions: {
      student: { tokenHash, generation: 2, revoked: false, cache: {} },
    },
    userClubMemberships: {
      student: { robotics: { role: "member", email: "student@d214.org" } },
    },
    clubCalendars: { robotics: { latestChange: "0000000000000042" } },
    clubs: { robotics: { name: "Robotics" } },
  };
  const setupReads = [];
  const admin = fakeAdmin(data, setupReads);
  const dependency = await readDependencyState(
    admin.database(), "student", window.dayKey, "student@d214.org"
  );
  data.calendarSubscriptions.student.cache[window.dayKey] = {
    body: "BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n",
    meta: {
      etag: "warm-etag",
      fingerprint: dependency.fingerprint,
      builtAt: 100,
    },
  };

  const reads = [];
  const response = await getCalendarResponse(fakeAdmin(data, reads), rawToken);
  assert.equal(response.status, 200);
  assert.equal(response.cacheHit, true);
  assert.equal(reads.some((value) => value.startsWith("/clubMeetings/")), false);
  assert.equal(reads.some((value) => /\/months\//.test(value)), false);
  assert.equal(reads.some((value) => value === "/users"), false);

  const conditionalReads = [];
  const conditional = await getCalendarResponse(
    fakeAdmin(data, conditionalReads), rawToken, { "if-none-match": '"warm-etag"' }
  );
  assert.equal(conditional.status, 304);
  assert.equal(conditionalReads.some((value) => value.endsWith("/body")), false);
});
