"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");
const { grantAdmin, listAdmins, revokeAdmin } = require("../lib/admin-management");
const { adminManagementHandler } = require("../lib/api");

const actor = { uid: "a", phsSuperAdmin: true };

function user(uid, email, claims = {}, overrides = {}) {
  return { uid, email, customClaims: claims, disabled: false, emailVerified: true, ...overrides };
}

function fakeAdmin(initialUsers) {
  const users = new Map(initialUsers.map((entry) => [entry.uid, entry]));
  let lock = null;
  const auth = {
    async verifyIdToken(token, checkRevoked) {
      assert.equal(token, "test-token");
      assert.equal(checkRevoked, true);
      return actor;
    },
    async getUser(uid) {
      const found = users.get(uid);
      if (!found) throw Object.assign(new Error("not found"), { code: "auth/user-not-found" });
      return { ...found, customClaims: { ...found.customClaims } };
    },
    async getUserByEmail(email) {
      const found = Array.from(users.values()).find((entry) => entry.email === email);
      if (!found) throw Object.assign(new Error("not found"), { code: "auth/user-not-found" });
      return this.getUser(found.uid);
    },
    async listUsers(_limit, pageToken) {
      const all = Array.from(users.values());
      const start = Number(pageToken || 0);
      return {
        users: all.slice(start, start + 2).map((entry) => ({ ...entry })),
        pageToken: start + 2 < all.length ? String(start + 2) : undefined,
      };
    },
    async setCustomUserClaims(uid, claims) {
      const found = users.get(uid);
      users.set(uid, { ...found, customClaims: { ...claims } });
    },
  };
  const ref = {
    async transaction(update) {
      const next = update(lock);
      if (next === undefined) return { committed: false, snapshot: { val: () => lock } };
      lock = next;
      return { committed: true, snapshot: { val: () => lock } };
    },
  };
  return { auth: () => auth, database: () => ({ ref: () => ref }), users };
}

async function request(admin, method, path, body = null, authorization = "Bearer test-token") {
  const response = {
    statusCode: 200,
    status(code) { this.statusCode = code; return this; },
    set() { return this; },
    json(value) { this.body = value; return this; },
  };
  await adminManagementHandler(admin)({
    method, path, body, query: {}, get: () => authorization,
  }, response);
  return response;
}

test("only a current live admin can list claim holders", async () => {
  const admin = fakeAdmin([
    user("a", "first@gmail.com", { phsSuperAdmin: true }),
    user("b", "second@gmail.com", { phsSuperAdmin: true }),
    user("c", "other@gmail.com"),
  ]);
  assert.deepEqual((await listAdmins(admin, actor)).map((entry) => entry.uid), ["a", "b"]);
  admin.users.get("a").customClaims = {};
  await assert.rejects(listAdmins(admin, actor), { status: 403 });
});

test("grant requires a verified existing account and preserves other claims", async () => {
  const admin = fakeAdmin([
    user("a", "first@gmail.com", { phsSuperAdmin: true }),
    user("b", "second@gmail.com", { otherRole: "member" }),
    user("c", "third@gmail.com", {}, { emailVerified: false }),
  ]);
  await assert.rejects(grantAdmin(admin, actor, { email: "missing@gmail.com" }), { status: 404 });
  await assert.rejects(grantAdmin(admin, actor, { email: "third@gmail.com" }), { status: 409 });
  await assert.rejects(grantAdmin(admin, actor, { email: "outside@example.com" }), { status: 400 });
  const granted = await grantAdmin(admin, actor, { email: " SECOND@gmail.com " });
  assert.equal(granted.uid, "b");
  assert.deepEqual(admin.users.get("b").customClaims, {
    otherRole: "member", phsSuperAdmin: true,
  });
});

test("revoke preserves other claims and refuses to remove the last active admin", async () => {
  const admin = fakeAdmin([
    user("a", "first@gmail.com", { phsSuperAdmin: true }),
    user("b", "second@gmail.com", { phsSuperAdmin: true, otherRole: "member" }),
  ]);
  assert.deepEqual(await revokeAdmin(admin, actor, { uid: "b" }), { removedUID: "b" });
  assert.deepEqual(admin.users.get("b").customClaims, { otherRole: "member" });
  await assert.rejects(revokeAdmin(admin, actor, { uid: "a" }), { status: 409 });
  assert.equal(admin.users.get("a").customClaims.phsSuperAdmin, true);
});

test("concurrent removals cannot both pass the mutation lock", async () => {
  const admin = fakeAdmin([
    user("a", "first@gmail.com", { phsSuperAdmin: true }),
    user("b", "second@gmail.com", { phsSuperAdmin: true }),
  ]);
  const results = await Promise.allSettled([
    revokeAdmin(admin, actor, { uid: "b" }),
    revokeAdmin(admin, { uid: "b", phsSuperAdmin: true }, { uid: "a" }),
  ]);
  assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
  assert.equal(Array.from(admin.users.values()).filter((entry) =>
    entry.customClaims.phsSuperAdmin === true).length, 1);
});

test("an admin who removes themself cannot use a stale token to regain access", async () => {
  const admin = fakeAdmin([
    user("a", "first@gmail.com", { phsSuperAdmin: true }),
    user("b", "second@gmail.com", { phsSuperAdmin: true }),
  ]);
  await revokeAdmin(admin, actor, { uid: "a" });
  await assert.rejects(
    grantAdmin(admin, actor, { email: "first@gmail.com" }),
    { status: 403 }
  );
  assert.equal(admin.users.get("a").customClaims.phsSuperAdmin, undefined);
});

test("the authenticated API routes list, grant, and remove administrators", async () => {
  const admin = fakeAdmin([
    user("a", "first@gmail.com", { phsSuperAdmin: true }),
    user("b", "second@gmail.com"),
  ]);
  const before = await request(admin, "GET", "/admins");
  assert.equal(before.statusCode, 200);
  assert.deepEqual(before.body.map((entry) => entry.uid), ["a"]);
  const granted = await request(admin, "PUT", "/admins", { email: "second@gmail.com" });
  assert.equal(granted.statusCode, 200);
  assert.equal(granted.body.uid, "b");
  const removed = await request(admin, "DELETE", "/admins", { uid: "b" });
  assert.equal(removed.statusCode, 200);
  assert.deepEqual(removed.body, { removedUID: "b" });
});

test("the admin API rejects unsigned requests and stale administrator claims", async () => {
  const admin = fakeAdmin([user("a", "first@gmail.com", { phsSuperAdmin: true })]);
  assert.equal((await request(admin, "GET", "/admins", null, "")).statusCode, 401);
  admin.users.get("a").customClaims = {};
  assert.equal((await request(admin, "GET", "/admins")).statusCode, 403);
});
