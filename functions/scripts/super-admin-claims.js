#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const { normalizedEmail } = require("../lib/access");

function validateManifest(manifest, projectID) {
  if (manifest?.projectId !== projectID || !Array.isArray(manifest.emails) || !manifest.emails.length) {
    throw new Error("The admin manifest must list emails and match --project exactly.");
  }
  const emails = manifest.emails.map(normalizedEmail);
  if (emails.some((email) => !email) || new Set(emails).size !== emails.length) {
    throw new Error("The admin manifest contains an empty or duplicate email.");
  }
  return emails;
}

async function intendedUsers(auth, manifest, projectID) {
  const users = [];
  for (const email of validateManifest(manifest, projectID)) {
    const user = await auth.getUserByEmail(email);
    if (normalizedEmail(user.email) !== email || user.disabled || !user.emailVerified) {
      throw new Error(`Admin ${email} must have a matching, enabled, verified Auth account.`);
    }
    users.push(user);
  }
  if (new Set(users.map((user) => user.uid)).size !== users.length) {
    throw new Error("The admin manifest resolves multiple emails to one UID.");
  }
  return users;
}

async function unexpectedClaimUIDs(auth, intendedUIDs) {
  const unexpected = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) {
      if (user.customClaims?.phsSuperAdmin === true && !intendedUIDs.has(user.uid)) {
        unexpected.push(user.uid);
      }
    }
    pageToken = page.pageToken;
  } while (pageToken);
  return unexpected;
}

async function inspectAdmins(auth, manifest, projectID) {
  const users = await intendedUsers(auth, manifest, projectID);
  const unexpected = await unexpectedClaimUIDs(auth, new Set(users.map((user) => user.uid)));
  return {
    projectId: projectID,
    intended: users.map((user) => ({
      uid: user.uid,
      email: normalizedEmail(user.email),
      provisioned: user.customClaims?.phsSuperAdmin === true,
    })),
    unexpectedClaimUIDs: unexpected,
  };
}

async function bootstrapAdmins(auth, manifest, projectID, backupPath) {
  if (!backupPath) throw new Error("Bootstrap requires --backup for rollback.");
  const users = await intendedUsers(auth, manifest, projectID);
  const unexpected = await unexpectedClaimUIDs(auth, new Set(users.map((user) => user.uid)));
  if (unexpected.length) throw new Error(`Unexpected super-admin claims: ${unexpected.join(", ")}`);

  const backup = {
    version: 1, projectId: projectID, createdAt: new Date().toISOString(),
    users: users.map((user) => ({
      uid: user.uid,
      email: normalizedEmail(user.email),
      hadClaim: Object.hasOwn(user.customClaims || {}, "phsSuperAdmin"),
      previousClaim: user.customClaims?.phsSuperAdmin ?? null,
    })),
  };
  fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2) + "\n", {
    flag: "wx", mode: 0o600,
  });

  for (const user of users) {
    const current = await auth.getUser(user.uid);
    if (normalizedEmail(current.email) !== normalizedEmail(user.email) ||
        current.disabled || !current.emailVerified ||
        JSON.stringify(current.customClaims || {}) !== JSON.stringify(user.customClaims || {})) {
      throw new Error(`Auth account ${user.uid} changed during bootstrap; use the backup to roll back.`);
    }
    await auth.setCustomUserClaims(user.uid, {
      ...current.customClaims, phsSuperAdmin: true,
    });
  }
  const report = await inspectAdmins(auth, manifest, projectID);
  if (report.unexpectedClaimUIDs.length || report.intended.some((user) => !user.provisioned)) {
    throw new Error("Provisioning verification failed; use the backup to roll back.");
  }
  return report;
}

async function rollbackAdmins(auth, backup, projectID) {
  if (backup?.version !== 1 || backup.projectId !== projectID || !Array.isArray(backup.users)) {
    throw new Error("The rollback backup must match --project and schema version 1.");
  }
  const current = await Promise.all(backup.users.map(async (entry) => {
    const user = await auth.getUser(entry.uid);
    const priorClaimStillPresent = entry.hadClaim
      ? user.customClaims?.phsSuperAdmin === entry.previousClaim
      : !Object.hasOwn(user.customClaims || {}, "phsSuperAdmin");
    if (normalizedEmail(user.email) !== entry.email ||
        (user.customClaims?.phsSuperAdmin !== true && !priorClaimStillPresent)) {
      throw new Error(`Auth account ${entry.uid} changed; rollback stopped before writes.`);
    }
    return { entry, user };
  }));
  for (const { entry, user } of current) {
    const claims = { ...user.customClaims };
    if (entry.hadClaim) claims.phsSuperAdmin = entry.previousClaim;
    else delete claims.phsSuperAdmin;
    await auth.setCustomUserClaims(entry.uid, claims);
  }
  return { projectId: projectID, restoredUIDs: current.map(({ entry }) => entry.uid) };
}

async function main(argv) {
  const [command, ...argumentsList] = argv;
  const options = {};
  for (let index = 0; index < argumentsList.length; index += 2) {
    const flag = argumentsList[index];
    if (!flag?.startsWith("--") || !argumentsList[index + 1]) throw new Error(`Invalid argument: ${flag}`);
    options[flag.slice(2)] = argumentsList[index + 1];
  }
  const projectID = options.project;
  if (!projectID) throw new Error("Pass --project with the exact Firebase project ID.");
  if (!["plan", "bootstrap", "verify", "rollback"].includes(command)) {
    throw new Error("Use plan, bootstrap, verify, or rollback.");
  }
  if (["bootstrap", "rollback"].includes(command) && options["confirm-project"] !== projectID) {
    throw new Error("Claim writes require --confirm-project matching --project.");
  }
  if (command !== "rollback" && !options.emails) throw new Error("Pass --emails with the intended-admin manifest.");
  if (["bootstrap", "rollback"].includes(command) && !options.backup) {
    throw new Error("Bootstrap and rollback require --backup.");
  }
  const manifest = command === "rollback" ? null : JSON.parse(fs.readFileSync(options.emails, "utf8"));
  const backup = command === "rollback" ? JSON.parse(fs.readFileSync(options.backup, "utf8")) : null;
  const { initializeApp, applicationDefault, deleteApp } = require("firebase-admin/app");
  const { getAuth } = require("firebase-admin/auth");
  const app = initializeApp({ credential: applicationDefault(), projectId: projectID }, "super-admin-claims");
  try {
    const auth = getAuth(app);
    const report = command === "rollback"
      ? await rollbackAdmins(auth, backup, projectID)
      : command === "bootstrap"
        ? await bootstrapAdmins(auth, manifest, projectID, options.backup)
        : await inspectAdmins(auth, manifest, projectID);
    process.stdout.write(JSON.stringify(report, null, 2) + "\n");
    if (command === "verify" &&
        (report.unexpectedClaimUIDs.length || report.intended.some((user) => !user.provisioned))) {
      process.exitCode = 1;
    }
  } finally {
    await deleteApp(app);
  }
}

if (require.main === module) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = { bootstrapAdmins, inspectAdmins, rollbackAdmins, validateManifest };
