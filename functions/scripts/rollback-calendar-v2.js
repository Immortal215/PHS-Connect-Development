#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { createAdminServices } = require("../lib/firebase-admin-services");

function argumentsFrom(argv) {
  const result = { apply: false };
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] === "--apply") result.apply = true;
    else if (argv[index].startsWith("--")) result[argv[index].slice(2)] = argv[++index];
  }
  return result;
}

function epochSeconds(value) {
  const number = Number(value || 0);
  return number > 1e12 ? number / 1000 : number;
}

function newerThan(value, cutoff) {
  if (!value || typeof value !== "object") return false;
  if (epochSeconds(value.updatedAt || value.lastUpdated || value.committedAt) > cutoff) return true;
  return Object.values(value).some((child) => newerThan(child, cutoff));
}

async function main() {
  const options = argumentsFrom(process.argv.slice(2));
  if (!options.backup) throw new Error("Pass --backup /absolute/path.json.");
  const backupPath = path.resolve(options.backup);
  if (!path.isAbsolute(options.backup)) throw new Error("The backup path must be absolute.");
  const backup = JSON.parse(fs.readFileSync(backupPath, "utf8"));
  const projectID = options.project || process.env.GCLOUD_PROJECT || process.env.GCLOUD_PROJECT_ID;
  if (!projectID || backup.projectID !== projectID) throw new Error("Backup and requested project do not match.");
  if (options.apply && options["confirm-project"] !== projectID) {
    throw new Error("Apply requires --confirm-project matching --project.");
  }
  const admin = createAdminServices({ projectId: projectID, databaseURL: options["database-url"] });
  const db = admin.database();
  const completed = (await db.ref("/internal/migrations/calendar-v2/complete").get()).val();
  const cutoff = Number(completed?.completedAt || 0) / (Number(completed?.completedAt || 0) > 1e12 ? 1000 : 1);
  const current = await Promise.all([
    db.ref("/clubs").get(), db.ref("/clubMemberships").get(),
    db.ref("/clubMeetings").get(), db.ref("/clubCalendars").get(),
  ]);
  const hasPostCutoverWrites = cutoff > 0 && current.some((snapshot) => newerThan(snapshot.val(), cutoff));
  const report = {
    mode: options.apply ? "apply" : "dry-run",
    projectID,
    migrationCompletedAt: cutoff || null,
    hasPostCutoverWrites,
    restoreRoots: Object.keys(backup.roots || {}),
    restoreLegacyTokenCount: Object.keys(backup.legacyFCMTokens || {}).length,
  };
  console.log(JSON.stringify(report, null, 2));
  if (!options.apply) return;
  if (hasPostCutoverWrites) {
    throw new Error("Rollback refused: new-format writes exist after cutover. Export current data and use a forward repair or reviewed merge so those writes are not lost.");
  }
  const updates = {};
  for (const [key, value] of Object.entries(backup.roots || {})) updates[key] = value;
  for (const [uid, token] of Object.entries(backup.legacyFCMTokens || {})) {
    updates[`users/${uid}/fcmToken`] = token;
  }
  await db.ref().update(updates);
  console.log(JSON.stringify({ rolledBack: true, projectID }));
}

if (require.main === module) main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});

module.exports = { epochSeconds, newerThan };
