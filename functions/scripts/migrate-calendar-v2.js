#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { isEligibleAuthUser } = require("../lib/access");
const { monthKeys, sha256 } = require("../lib/calendar-core");
const { createAdminServices } = require("../lib/firebase-admin-services");
const {
  canonicalLegacyMeeting: canonicalMeeting,
  chicagoEpoch,
  legacyMeetingID: meetingID,
  parseLegacyParts,
  strictLegacyDate,
  strictLegacyDateOnly,
} = require("../lib/legacy-calendar");
const { acquireLocks, releaseLocks } = require("../lib/locks");
const { legacyVisibilityClaimUpdates } = require("../lib/meeting-visibility");

const MIGRATION_ID = "calendar-v2";
const SCOPED_BACKUP_PATHS = [
  "clubMemberships", "userClubMemberships", "clubJoinRequests", "clubMeetings",
  "clubCalendars", "internal/unresolvedIdentities", "internal/identityAccess",
  "internal/meetingVisibilityClaims", "internal/meetingVisibilityClaimsByMeeting",
  `internal/migrations/${MIGRATION_ID}`,
];

function parseArguments(argv) {
  const result = { apply: false };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "--apply") result.apply = true;
    else if (value.startsWith("--")) result[value.slice(2)] = argv[++index];
  }
  return result;
}

function normalizeEmail(value) { return String(value || "").trim().toLowerCase(); }
function safeObject(value) { return value && typeof value === "object" ? value : {}; }
function arrayValues(value) { return Array.isArray(value) ? value.filter(Boolean) : Object.values(safeObject(value)).filter(Boolean); }

async function authEmailMap(admin) {
  const result = new Map();
  const uids = [];
  let pageToken;
  do {
    const page = await admin.auth().listUsers(1000, pageToken);
    for (const user of page.users) {
      const email = normalizeEmail(user.email);
      uids.push(user.uid);
      if (isEligibleAuthUser(user)) result.set(email, user.uid);
    }
    pageToken = page.pageToken;
  } while (pageToken);
  return { emailToUID: result, uids };
}

function authEmailMapFromExport(value) {
  const result = new Map();
  const uids = [];
  for (const user of arrayValues(value?.users)) {
    const uid = String(user.localId || user.uid || "").trim();
    const email = normalizeEmail(user.email);
    if (!uid) continue;
    uids.push(uid);
    if (isEligibleAuthUser(user)) result.set(email, uid);
  }
  return { emailToUID: result, uids };
}

function stripExportMetadata(value) {
  if (Array.isArray(value)) return value.map(stripExportMetadata);
  if (!value || typeof value !== "object") return value;
  if (Object.hasOwn(value, ".value")) return stripExportMetadata(value[".value"]);
  return Object.fromEntries(Object.entries(value)
    .filter(([key]) => !key.startsWith("."))
    .map(([key, child]) => [key, stripExportMetadata(child)]));
}

function offlineDatabase(exported) {
  const root = stripExportMetadata(exported);
  return {
    ref(referencePath = "/") {
      const parts = String(referencePath).split("/").filter(Boolean);
      let value = root;
      for (const part of parts) value = value && typeof value === "object" ? value[part] : null;
      return {
        async get() {
          return {
            val: () => value ?? null,
            exists: () => value != null,
            numChildren: () => Object.keys(safeObject(value)).length,
          };
        },
      };
    },
  };
}

async function legacyFCMTokens(db, uids) {
  const values = {};
  for (let index = 0; index < uids.length; index += 50) {
    const rows = await Promise.all(uids.slice(index, index + 50).map(async (uid) => ({
      uid, value: (await db.ref(`/users/${uid}/fcmToken`).get()).val(),
    })));
    for (const row of rows) if (row.value) values[row.uid] = row.value;
  }
  return values;
}

async function writeScopedBackup(db, clubs, oldTokens, projectID, outputPath) {
  const backupPath = path.resolve(outputPath);
  if (fs.existsSync(backupPath)) throw new Error(`Refusing to overwrite backup: ${backupPath}`);
  const backupEntries = await Promise.all(SCOPED_BACKUP_PATHS.map(async (backupKey) => [
    backupKey, (await db.ref(`/${backupKey}`).get()).val() ?? null,
  ]));
  fs.writeFileSync(backupPath, `${JSON.stringify({
    projectID,
    exportedAt: new Date().toISOString(),
    roots: { clubs, ...Object.fromEntries(backupEntries) },
    legacyFCMTokens: oldTokens,
  }, null, 2)}\n`, { flag: "wx", mode: 0o600 });
}


function membershipValue(uid, email, role, timestamp, calendarCursor) {
  return { role, email, emailHash: sha256(email), joinedAt: timestamp, updatedAt: timestamp, calendarCursor };
}

async function buildPlan(db, clubs, emailToUID) {
  const updates = {};
  const report = { clubs: 0, meetings: 0, visibilityClaims: 0, memberships: 0, joinRequests: 0, malformedDates: [], missingRevisionTimestamps: [], unresolvedIdentities: [], unresolvedVisibility: [], conflicts: [] };
  for (const [clubID, original] of Object.entries(clubs)) {
    report.clubs += 1;
    const club = { ...safeObject(original) };
    const leaders = Array.from(new Set(arrayValues(club.leaders).map(normalizeEmail).filter(Boolean)));
    const members = Array.from(new Set(arrayValues(club.members).map(normalizeEmail).filter(Boolean))).filter((email) => !leaders.includes(email));
    const timestamp = Number(club.lastUpdated || 0);
    for (const [role, emails] of [["member", members], ["leader", leaders]]) {
      for (const email of emails) {
        const uid = emailToUID.get(email);
        const hash = sha256(email);
        if (!uid) {
          updates[`internal/unresolvedIdentities/${clubID}/${hash}`] = { email, role, reason: "auth/user-not-found-or-unverified", updatedAt: timestamp };
          updates[`internal/identityAccess/${hash}/${clubID}`] = { email, role, state: "active", lastUID: null, updatedAt: timestamp };
          report.unresolvedIdentities.push({ clubID, email, role });
          continue;
        }
        const value = membershipValue(uid, email, role, timestamp);
        updates[`clubMemberships/${clubID}/${uid}`] = value;
        updates[`userClubMemberships/${uid}/${clubID}`] = value;
        updates[`internal/unresolvedIdentities/${clubID}/${hash}`] = null;
        updates[`internal/identityAccess/${hash}/${clubID}`] = { email, role, state: "active", lastUID: uid, updatedAt: timestamp };
        report.memberships += 1;
      }
    }
    const pending = Array.from(new Set(arrayValues(club.pendingMemberRequests).map(normalizeEmail).filter(Boolean)));
    for (const email of pending) {
      const uid = emailToUID.get(email);
      const hash = sha256(email);
      if (uid) {
        updates[`clubJoinRequests/${clubID}/${uid}`] = { email, requestedAt: timestamp, updatedAt: timestamp };
        updates[`userClubMemberships/${uid}/${clubID}`] = { role: "pending", email, requestedAt: timestamp, updatedAt: timestamp };
        updates[`internal/unresolvedIdentities/${clubID}/${hash}`] = null;
        updates[`internal/identityAccess/${hash}/${clubID}`] = { email, role: "pending", state: "pending", lastUID: uid, updatedAt: timestamp };
        report.joinRequests += 1;
      } else {
        updates[`internal/unresolvedIdentities/${clubID}/${hash}`] = { email, role: "pending", reason: "auth/user-not-found-or-unverified", updatedAt: timestamp };
        updates[`internal/identityAccess/${hash}/${clubID}`] = { email, role: "pending", state: "pending", lastUID: null, updatedAt: timestamp };
        report.unresolvedIdentities.push({ clubID, email, role: "pending" });
      }
    }
    const meetings = arrayValues(club.meetingTimes);
    const [schemaSnapshot, cursorSnapshot, checkpointSnapshot] = await Promise.all([
      db.ref(`/clubCalendars/${clubID}/schemaVersion`).get(),
      db.ref(`/clubCalendars/${clubID}/latestChange`).get(),
      db.ref(`/internal/migrations/${MIGRATION_ID}/checkpoints/${clubID}`).get(),
    ]);
    const alreadyV2 = Number(schemaSnapshot.val() || 0) >= 2;
    const initialCursor = alreadyV2
      ? String(cursorSnapshot.val() || "") : meetings.length ? "0000000000000001" : "";
    for (const pathKey of Object.keys(updates)) {
      if ((pathKey.startsWith(`clubMemberships/${clubID}/`) ||
           (pathKey.startsWith("userClubMemberships/") && pathKey.endsWith(`/${clubID}`))) &&
          updates[pathKey]?.role) {
        updates[pathKey].calendarCursor = initialCursor;
      }
    }
    const changeItems = [];
    if (!alreadyV2) for (let index = 0; index < meetings.length; index += 1) {
        const canonical = canonicalMeeting(clubID, index, meetings[index], emailToUID, report, timestamp);
        if (!canonical) continue;
        const existing = (await db.ref(`/clubMeetings/${clubID}/${canonical.meetingID}`).get()).val();
        if (existing && JSON.stringify(existing) !== JSON.stringify(canonical)) {
          report.conflicts.push({ clubID, meetingID: canonical.meetingID, reason: "canonical-record-differs" });
          continue;
        }
        updates[`clubMeetings/${clubID}/${canonical.meetingID}`] = canonical;
        const visibilityEmails = arrayValues(meetings[index].visibleByArray).map(normalizeEmail).filter(Boolean);
        legacyVisibilityClaimUpdates(
          updates, canonical.meetingID, clubID, visibilityEmails, emailToUID, timestamp
        );
        report.visibilityClaims += new Set(visibilityEmails).size;
        for (const month of monthKeys(canonical.startDate, canonical.endDateExclusive)) {
          updates[`clubCalendars/${clubID}/months/${month}/${canonical.meetingID}`] = 1;
        }
        changeItems.push({ meetingID: canonical.meetingID, operation: "upsert", meetingRevision: 1, startDate: canonical.startDate, endDateExclusive: canonical.endDateExclusive, updatedAt: timestamp });
        report.meetings += 1;
      }
    if (!alreadyV2 && changeItems.length) {
      const cursor = "0000000000000001";
      updates[`clubCalendars/${clubID}/sequence`] = 1;
      updates[`clubCalendars/${clubID}/latestChange`] = cursor;
      updates[`clubCalendars/${clubID}/minimumChange`] = cursor;
      updates[`clubCalendars/${clubID}/updatedAt`] = timestamp;
      updates[`clubCalendars/${clubID}/changes/${cursor}`] = { operationID: `migration-${clubID}`, committedAt: timestamp, items: changeItems };
    } else if (!alreadyV2) {
      updates[`clubCalendars/${clubID}/sequence`] = 0;
      updates[`clubCalendars/${clubID}/latestChange`] = "";
      updates[`clubCalendars/${clubID}/minimumChange`] = "";
      updates[`clubCalendars/${clubID}/updatedAt`] = timestamp;
    }
    // The migration is one-way: v2 is authoritative. Every superseded field
    // under /clubs remains stored as a frozen snapshot after cutover; deployed
    // app and backend code must neither read it as authoritative nor update it.
    if (!alreadyV2) updates[`clubCalendars/${clubID}/schemaVersion`] = 2;
    updates[`clubs/${clubID}/calendarStorageVersion`] = 2;
    updates[`clubs/${clubID}/membershipStorageVersion`] = 2;
    const checkpoint = checkpointSnapshot.val() || {};
    if (!checkpoint.complete) {
      let meetingCount = changeItems.length;
      if (alreadyV2) {
        const canonicalSnapshot = await db.ref(`/clubMeetings/${clubID}`).get();
        meetingCount = Object.keys(safeObject(canonicalSnapshot.val())).length;
      }
      updates[`internal/migrations/${MIGRATION_ID}/checkpoints/${clubID}`] = {
        complete: true,
        sourceHash: sha256(JSON.stringify(original)),
        meetingCount,
        adoptedExistingV2: alreadyV2,
        visibilityClaimsVersion: 1,
        membershipResolutionVersion: 2,
        updatedAt: timestamp,
      };
    } else if (Number(checkpoint.membershipResolutionVersion || 0) < 2) {
      updates[`internal/migrations/${MIGRATION_ID}/checkpoints/${clubID}/membershipResolutionVersion`] = 2;
      updates[`internal/migrations/${MIGRATION_ID}/checkpoints/${clubID}/membershipRepairedAt`] = timestamp;
    }
  }
  return { updates, report };
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const projectID = options.project || process.env.GCLOUD_PROJECT || process.env.GCLOUD_PROJECT_ID;
  if (!projectID) throw new Error("Pass --project with the exact Firebase project ID.");
  if (options.apply && options["confirm-project"] !== projectID) throw new Error("Apply requires --confirm-project matching --project.");
  if (options.apply && !options.backup) throw new Error("Apply requires --backup /absolute/path.json.");
  const databaseExportPath = options["database-export"];
  const authExportPath = options["auth-export"];
  if (Boolean(databaseExportPath) !== Boolean(authExportPath)) {
    throw new Error("Offline dry-run requires both --database-export and --auth-export.");
  }
  if (options.apply && databaseExportPath) {
    throw new Error("Offline exports are read-only; --apply requires live Admin credentials.");
  }
  let db;
  let authState;
  let admin;
  if (databaseExportPath) {
    const databaseExport = JSON.parse(fs.readFileSync(path.resolve(databaseExportPath), "utf8"));
    const authExport = JSON.parse(fs.readFileSync(path.resolve(authExportPath), "utf8"));
    db = offlineDatabase(databaseExport);
    authState = authEmailMapFromExport(authExport);
  } else {
    admin = createAdminServices({ projectId: projectID, databaseURL: options["database-url"] });
    db = admin.database();
    authState = await authEmailMap(admin);
  }
  const clubs = (await db.ref("/clubs").get()).val() || {};
  const oldTokens = await legacyFCMTokens(db, authState.uids);
  if (options["scoped-backup"]) {
    await writeScopedBackup(db, clubs, oldTokens, projectID, options["scoped-backup"]);
  }
  if (options.apply) {
    await writeScopedBackup(db, clubs, oldTokens, projectID, options.backup);
  }
  const emailToUID = authState.emailToUID;
  const { updates, report } = await buildPlan(db, clubs, emailToUID);
  for (const uid of Object.keys(oldTokens)) updates[`users/${uid}/fcmToken`] = null;
  report.legacyFCMTokensRemoved = Object.keys(oldTokens).length;
  if (options["plan-output"]) {
    if (options.apply) throw new Error("--plan-output is only available for a dry-run.");
    const outputPath = path.resolve(options["plan-output"]);
    if (fs.existsSync(outputPath)) throw new Error(`Refusing to overwrite migration plan: ${outputPath}`);
    const plan = {
      ...updates,
      [`internal/migrations/${MIGRATION_ID}/complete`]: {
        projectID,
        completedAt: { ".sv": "timestamp" },
        sourceClubCount: Object.keys(clubs).length,
        applicationMode: "firebase-cli-atomic-update",
        visibilityClaimsVersion: 1,
      },
    };
    fs.writeFileSync(outputPath, `${JSON.stringify(plan, null, 2)}\n`, {
      flag: "wx",
      mode: 0o600,
    });
  }
  console.log(JSON.stringify({ mode: options.apply ? "apply" : "dry-run", projectID, updatePaths: Object.keys(updates).length, report }, null, 2));
  if (!options.apply) return;
  if (report.conflicts.length || report.malformedDates.length) throw new Error("Validation issues must be reconciled before apply; no database writes were made.");
  // Apply one club at a time under the same lock used by the v2 backend. New
  // clients can keep writing already-converted clubs while the migration runs.
  for (const clubID of Object.keys(clubs).sort()) {
    const lock = await acquireLocks(db, "calendarLocks", [clubID], 60000);
    try {
      const liveClub = (await db.ref(`/clubs/${clubID}`).get()).val();
      if (!liveClub) continue;
      const clubPlan = await buildPlan(db, { [clubID]: liveClub }, emailToUID);
      if (clubPlan.report.conflicts.length || clubPlan.report.malformedDates.length) {
        throw new Error(`Club ${clubID} changed after validation and needs reconciliation.`);
      }
      await db.ref().update(clubPlan.updates);
    } finally {
      await releaseLocks(lock);
    }
  }
  const tokenUpdates = Object.fromEntries(
    Object.keys(oldTokens).map((uid) => [`users/${uid}/fcmToken`, null])
  );
  if (Object.keys(tokenUpdates).length) await db.ref().update(tokenUpdates);
  const validationClubs = (await db.ref("/clubs").get()).val() || {};
  const validation = await buildPlan(db, validationClubs, emailToUID);
  if (validation.report.conflicts.length) throw new Error("Post-apply validation found conflicts. Preserve the backup and stop rollout.");
  await db.ref(`/internal/migrations/${MIGRATION_ID}/complete`).set({
    projectID,
    completedAt: admin.serverTimestamp,
    sourceClubCount: Object.keys(clubs).length,
    visibilityClaimsVersion: 1,
  });
  console.log(JSON.stringify({ applied: true, validated: true, projectID }));
}

if (require.main === module) main().catch((error) => { console.error(error.message); process.exitCode = 1; });

module.exports = {
  authEmailMapFromExport, buildPlan, canonicalMeeting, chicagoEpoch, meetingID,
  offlineDatabase, parseLegacyParts, strictLegacyDate, strictLegacyDateOnly,
  writeScopedBackup,
};
