"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const { deleteApp } = require("firebase-admin/app");
const { AuthErrorCode, FirebaseAuthError } = require("firebase-admin/auth");
const {
  FirebaseMessagingError, MessagingErrorCode,
} = require("firebase-admin/messaging");
const { createAdminServices } = require("../lib/firebase-admin-services");

test("modular Admin services preserve the backend service contract", async () => {
  const admin = createAdminServices({
    projectId: "phs-admin-compat-test",
    databaseURL: "http://127.0.0.1:9000?ns=phs-admin-compat-test",
  }, "phs-admin-compat-test");

  try {
    assert.equal(typeof admin.database().ref, "function");
    assert.equal(typeof admin.auth().verifyIdToken, "function");
    assert.equal(typeof admin.messaging().sendEachForMulticast, "function");
    assert.deepEqual(admin.serverTimestamp, { ".sv": "timestamp" });
  } finally {
    await deleteApp(admin.app);
  }
});

test("Admin 14 retains the Firebase error codes used by compatibility logic", () => {
  const missingUser = new FirebaseAuthError({
    code: AuthErrorCode.USER_NOT_FOUND,
    message: "missing",
  });
  const invalidToken = new FirebaseMessagingError({
    code: MessagingErrorCode.INVALID_REGISTRATION_TOKEN,
    message: "invalid",
  });
  const unregisteredToken = new FirebaseMessagingError({
    code: MessagingErrorCode.REGISTRATION_TOKEN_NOT_REGISTERED,
    message: "unregistered",
  });

  assert.equal(missingUser.code, "auth/user-not-found");
  assert.equal(invalidToken.code, "messaging/invalid-registration-token");
  assert.equal(unregisteredToken.code, "messaging/registration-token-not-registered");
});

test("Admin entry points do not restore the removed legacy namespace", () => {
  for (const relativePath of [
    "../index.js",
    "../scripts/migrate-calendar-v2.js",
    "../scripts/rollback-calendar-v2.js",
    "../scripts/validate-calendar-v2-readiness.js",
  ]) {
    const source = fs.readFileSync(path.resolve(__dirname, relativePath), "utf8");
    assert.equal(source.includes("require(\"firebase-admin\")"), false, relativePath);
    assert.equal(source.includes("admin.initializeApp("), false, relativePath);
  }
});
