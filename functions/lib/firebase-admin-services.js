"use strict";

const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getDatabase, ServerValue } = require("firebase-admin/database");
const { getMessaging } = require("firebase-admin/messaging");

function createAdminServices(options, name) {
  const app = initializeApp(options, name);
  return {
    app,
    auth: () => getAuth(app),
    database: () => getDatabase(app),
    messaging: () => getMessaging(app),
    serverTimestamp: ServerValue.TIMESTAMP,
  };
}

module.exports = { createAdminServices };
