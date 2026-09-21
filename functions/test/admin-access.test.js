"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { requireLeader } = require("../lib/access");
const { listRSVPs, syncClubCalendar } = require("../lib/meeting-service");
const { accessSnapshot } = require("../lib/membership-service");

function valueAt(root, path) {
  return path.split("/").filter(Boolean).reduce((value, key) => value?.[key], root);
}

function fakeAdmin(data, reads = []) {
  const db = {
    ref(path = "/") {
      return {
        async get() {
          reads.push(path);
          const value = valueAt(data, path);
          return { val: () => value, exists: () => value != null };
        },
        async update() {},
      };
    },
  };
  return { database: () => db };
}

const adminToken = {
  uid: "admin",
  email: "sharul.shah2008@gmail.com",
  email_verified: true,
};

test("superadmin leader authorization does not require a club membership record", async () => {
  const reads = [];
  const admin = fakeAdmin({ clubMemberships: { robotics: {} } }, reads);
  assert.equal(await requireLeader(admin.database(), "robotics", adminToken), "leader");
  assert.deepEqual(reads, ["/clubMemberships/robotics/admin"]);
});

test("superadmin can delta-sync an unjoined club without meeting body reads", async () => {
  const reads = [];
  const admin = fakeAdmin({
    clubCalendars: {
      robotics: { latestChange: "0000000000000007", minimumChange: "0000000000000001" },
    },
  }, reads);
  const result = await syncClubCalendar(admin, adminToken, {
    clubID: "robotics",
    start: "2026-08-01",
    end: "2027-09-01",
    after: "0000000000000007",
  });
  assert.deepEqual(result, {
    mode: "delta", latestChange: "0000000000000007", changes: [], hasMore: false,
  });
  assert.equal(reads.some((path) => path.startsWith("/clubMemberships/")), false);
  assert.equal(reads.some((path) => path.startsWith("/clubMeetings/")), false);
});

test("superadmin can view RSVP attendance for an unjoined club", async () => {
  const admin = fakeAdmin({
    clubMeetings: {
      robotics: {
        meeting1: {
          meetingID: "meeting1",
          clubID: "robotics",
          visibility: { mode: "public" },
        },
      },
    },
    clubMemberships: {
      robotics: {
        member: { role: "member", email: "member@d214.org" },
      },
    },
    meetingRSVPs: {
      meeting1: {
        member: { status: "going", active: true, updatedAt: 100 },
      },
    },
    users: { member: { userName: "Member" } },
  });
  const rows = await listRSVPs(admin, adminToken, "robotics", "meeting1");
  assert.deepEqual(rows, [{
    uid: "member", name: "Member", status: "going", active: true, updatedAt: 100,
  }]);
});

test("signed-in nonmembers load canonical club rosters without legacy club arrays", async () => {
  const admin = fakeAdmin({
    clubMemberships: {
      robotics: {
        leader: { role: "leader", email: "leader@d214.org" },
        member: { role: "member", email: "member@stu.d214.org" },
      },
    },
    clubJoinRequests: { robotics: {} },
  });

  const result = await accessSnapshot(admin, {
    uid: "visitor", email: "visitor@stu.d214.org", email_verified: true,
  }, "robotics");

  assert.equal(result.ownMembership, null);
  assert.equal(result.ownRequest, null);
  assert.deepEqual(result.memberships, {
    leader: { role: "leader", email: "leader@d214.org" },
    member: { role: "member", email: "member@stu.d214.org" },
  });
  assert.equal(Object.hasOwn(result, "requests"), false);
});
