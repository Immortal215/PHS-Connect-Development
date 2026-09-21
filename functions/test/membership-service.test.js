"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  membershipAction, reconcileIdentity, resolveEmails,
} = require("../lib/membership-service");
const { isAllowedIdentityEmail, isEligibleAuthUser } = require("../lib/access");
const { sha256 } = require("../lib/calendar-core");
const {
  publishVisibilityChanges, restoreIdentityVisibility,
} = require("../lib/meeting-visibility");

function fakeAdmin(users) {
  return {
    auth() {
      return {
        async getUserByEmail(email) {
          const user = users[email];
          if (!user) {
            const error = new Error("missing");
            error.code = "auth/user-not-found";
            throw error;
          }
          return user;
        },
      };
    },
  };
}

function membershipAdmin(initialValues) {
  const values = structuredClone(initialValues);
  const updates = [];
  const parts = (path) => String(path || "").split("/").filter(Boolean);
  const valueAt = (path) => parts(path).reduce(
    (value, part) => value == null ? undefined : value[part], values
  );
  const setValue = (path, value) => {
    const keys = parts(path);
    let parent = values;
    for (const key of keys.slice(0, -1)) parent = parent[key] ||= {};
    const key = keys.at(-1);
    if (value == null) delete parent[key];
    else parent[key] = value;
  };
  const snapshot = (value) => ({
    val: () => value ?? null,
    exists: () => value != null,
    child: (key) => snapshot(value?.[key]),
  });
  const db = {
    ref(path = "") {
      return {
        get: async () => snapshot(valueAt(path)),
        async transaction(transform) {
          const next = transform(valueAt(path));
          if (next === undefined) {
            return { committed: false, snapshot: snapshot(valueAt(path)) };
          }
          setValue(path, next);
          return { committed: true, snapshot: snapshot(next) };
        },
        async update(nextUpdates) {
          updates.push(nextUpdates);
          for (const [updatePath, value] of Object.entries(nextUpdates)) {
            setValue(updatePath, value);
          }
        },
      };
    },
  };
  return { database: () => db, values, updates };
}

function membershipInitialValues(action, uid) {
  const requestNeeded = action === "request";
  const membership = { role: "member", email: "member@stu.d214.org" };
  return {
    clubs: { robotics: { requestNeeded } },
    clubCalendars: { robotics: { latestChange: "0000000000000001" } },
    clubMemberships: {
      robotics: action === "leave" ? { [uid]: membership } : {},
    },
    userClubMemberships: action === "leave" ? { [uid]: { robotics: membership } } : {},
    userRSVPIndex: { [uid]: {} },
  };
}

const membershipIdentities = [
  {
    name: "verified",
    allowed: true,
    token: { uid: "verified", email: "member@stu.d214.org", email_verified: true },
  },
  {
    name: "unverified",
    allowed: false,
    token: { uid: "unverified", email: "member@stu.d214.org", email_verified: false },
  },
  {
    name: "unsupported",
    allowed: false,
    token: { uid: "unsupported", email: "member@prime8.dev", email_verified: true },
  },
  {
    name: "super admin",
    allowed: true,
    token: { uid: "admin", email: "sharul.shah2008@gmail.com", email_verified: false },
  },
];

for (const action of ["join", "request", "cancelRequest", "leave"]) {
  test(`${action} enforces canonical decoded identity eligibility`, async (t) => {
    for (const identity of membershipIdentities) {
      await t.test(identity.name, async () => {
        const admin = membershipAdmin(membershipInitialValues(action, identity.token.uid));
        const operation = membershipAction(admin, identity.token, { clubID: "robotics", action });
        if (!identity.allowed) {
          await assert.rejects(operation, (error) => error.status === 403);
          assert.equal(admin.updates.length, 0);
          return;
        }

        assert.deepEqual(await operation, { ok: true });
        assert.ok(admin.updates.length > 0);
        if (action === "join") {
          assert.equal(admin.values.clubMemberships.robotics[identity.token.uid].role, "member");
        } else if (action === "request") {
          assert.equal(admin.values.userClubMemberships[identity.token.uid].robotics.role, "pending");
          assert.equal(admin.values.clubJoinRequests.robotics[identity.token.uid].email, identity.token.email);
        } else if (action === "cancelRequest") {
          assert.equal(admin.values.userClubMemberships?.[identity.token.uid]?.robotics, undefined);
          assert.equal(
            admin.values.internal.identityAccess[sha256(identity.token.email)].robotics.state,
            "revoked"
          );
        } else {
          assert.equal(admin.values.clubMemberships.robotics[identity.token.uid], undefined);
        }
      });
    }
  });
}

test("identity eligibility matches the email domains accepted by the existing app", () => {
  assert.equal(isAllowedIdentityEmail("teacher@d214.org"), true);
  assert.equal(isAllowedIdentityEmail("student@stu.d214.org"), true);
  assert.equal(isAllowedIdentityEmail("legacy@gmail.com"), true);
  assert.equal(isAllowedIdentityEmail("person@prime8.dev"), false);
  assert.equal(isEligibleAuthUser({ email: "legacy@gmail.com", emailVerified: true }), true);
  assert.equal(isEligibleAuthUser({ email: "legacy@gmail.com", emailVerified: false }), false);
  assert.equal(isEligibleAuthUser({ email: "student@stu.d214.org", emailVerified: true, disabled: true }), false);
});

test("email resolution supports verified D214 subdomains and legacy Gmail accounts", async () => {
  const result = await resolveEmails(fakeAdmin({
    "active@d214.org": { uid: "active", emailVerified: true, disabled: false },
    "student@stu.d214.org": { uid: "student", emailVerified: true, disabled: false },
    "legacy@gmail.com": { uid: "legacy", emailVerified: true, disabled: false },
    "unsupported@prime8.dev": { uid: "unsupported", emailVerified: true, disabled: false },
    "disabled@d214.org": { uid: "disabled", emailVerified: true, disabled: true },
    "unverified@d214.org": { uid: "unverified", emailVerified: false, disabled: false },
  }), [
    "ACTIVE@d214.org", "student@stu.d214.org", "legacy@gmail.com",
    "unsupported@prime8.dev", "disabled@d214.org", "unverified@d214.org", "missing@d214.org",
  ]);

  assert.deepEqual(result.resolved, [
    { uid: "active", email: "active@d214.org" },
    { uid: "student", email: "student@stu.d214.org" },
    { uid: "legacy", email: "legacy@gmail.com" },
  ]);
  assert.deepEqual(result.unresolved.map((value) => value.reason), [
    "auth/unsupported-email", "auth/user-disabled", "auth/email-not-verified", "auth/user-not-found",
  ]);
});

test("large roster resolution uses bounded Firebase Auth batches", async () => {
  const emails = Array.from({ length: 205 }, (_, index) =>
    `student${index}@stu.d214.org`
  );
  const batchSizes = [];
  const admin = {
    auth() {
      return {
        async getUsers(identifiers) {
          batchSizes.push(identifiers.length);
          return {
            users: identifiers
              .filter((_, index) => index % 2 === 0)
              .map(({ email }) => ({ uid: `uid-${email}`, email, emailVerified: true, disabled: false })),
            notFound: identifiers.filter((_, index) => index % 2 !== 0),
          };
        },
      };
    },
  };

  const result = await resolveEmails(admin, emails);

  assert.deepEqual(batchSizes, [100, 100, 5]);
  assert.equal(result.resolved.length, 103);
  assert.equal(result.unresolved.length, 102);
  assert.equal(result.resolved[0].email, "student0@stu.d214.org");
  assert.deepEqual(result.unresolved[0], {
    email: "student1@stu.d214.org", reason: "auth/user-not-found",
  });
});

test("settled identity reconciliation performs no lock or database write", async () => {
  const email = "member@stu.d214.org";
  const uid = "member";
  const hash = sha256(email);
  const values = {
    [`/internal/identityAccess/${hash}`]: {
      robotics: { state: "active", role: "member", lastUID: uid },
    },
    [`/userClubMemberships/${uid}`]: {
      robotics: { role: "member", email },
    },
    [`/internal/meetingVisibilityClaims/${hash}`]: {
      meeting: {
        state: "active", clubID: "robotics", email, lastUID: uid,
      },
    },
  };
  let transactions = 0;
  let writes = 0;
  const admin = {
    database() {
      return {
        ref(path) {
          return {
            get: async () => ({ val: () => values[path] || null }),
            transaction: async () => {
              transactions += 1;
              throw new Error("A settled identity must not acquire a lock.");
            },
            update: async () => { writes += 1; },
          };
        },
      };
    },
  };

  const result = await reconcileIdentity(admin, {
    uid, email, email_verified: true,
  });

  assert.deepEqual(result, { restored: [] });
  assert.equal(transactions, 0);
  assert.equal(writes, 0);
});

test("verified identity reconciliation restores targeted meeting visibility and publishes a delta", async () => {
  const values = {
    "/clubMeetings/robotics/meeting-1": {
      meetingID: "meeting-1", clubID: "robotics", revision: 1,
      startDate: "2026-09-10", endDateExclusive: "2026-09-11",
      visibility: { mode: "uids", uids: { oldUID: true } },
    },
    "/clubCalendars/robotics/sequence": 4,
    "/clubMemberships/robotics": {
      newUID: { role: "member", email: "member@d214.org" },
    },
  };
  const db = {
    ref(path) { return { get: async () => ({ val: () => values[path] || null }) }; },
  };
  const updates = {};
  const changes = await restoreIdentityVisibility(db, updates, "emailHash", "newUID", "member@d214.org", {
    "meeting-1": {
      clubID: "robotics", email: "member@d214.org", state: "active", lastUID: "oldUID",
    },
  }, 200);
  await publishVisibilityChanges(db, updates, changes, "identity-test", 200);

  assert.equal(updates["clubMeetings/robotics/meeting-1"].visibility.uids.oldUID, undefined);
  assert.equal(updates["clubMeetings/robotics/meeting-1"].visibility.uids.newUID, true);
  assert.equal(updates["clubMeetings/robotics/meeting-1"].revision, 2);
  assert.equal(updates["internal/meetingVisibilityClaims/emailHash/meeting-1/lastUID"], "newUID");
  assert.equal(updates["clubCalendars/robotics/latestChange"], "0000000000000005");
  assert.equal(Object.keys(updates).some((key) => key.startsWith("userClubMemberships/")), false);
  assert.equal(Object.keys(updates).some((key) => key.includes("meetingNotificationJobs")), false);
});
