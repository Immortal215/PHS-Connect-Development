#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { isEligibleAuthUser } = require("../lib/access");
const { sha256 } = require("../lib/calendar-core");
const { legacyMeetingID } = require("./lib/legacy-calendar");

function options(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index].startsWith("--")) result[argv[index].slice(2)] = argv[++index];
  }
  return result;
}

function stripExportMetadata(value) {
  if (Array.isArray(value)) return value.map(stripExportMetadata);
  if (!value || typeof value !== "object") return value;
  if (Object.hasOwn(value, ".value")) return stripExportMetadata(value[".value"]);
  return Object.fromEntries(Object.entries(value)
    .filter(([key]) => !key.startsWith("."))
    .map(([key, child]) => [key, stripExportMetadata(child)]));
}

function values(value) {
  if (Array.isArray(value)) return value.filter(Boolean);
  return Object.values(value && typeof value === "object" ? value : {}).filter(Boolean);
}

function normalizedEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function authEmailMap(exported) {
  const result = new Map();
  for (const user of values(exported?.users)) {
    const email = normalizedEmail(user.email);
    const uid = String(user.localId || user.uid || "").trim();
    if (uid && isEligibleAuthUser(user)) {
      result.set(email, uid);
    }
  }
  return result;
}

function main() {
  const args = options(process.argv.slice(2));
  if (!args.project || !args["database-export"] || !args["auth-export"] || !args["plan-output"]) {
    throw new Error("Pass --project, --database-export, --auth-export, and --plan-output.");
  }
  const outputPath = path.resolve(args["plan-output"]);
  if (fs.existsSync(outputPath)) throw new Error(`Refusing to overwrite plan: ${outputPath}`);
  const root = stripExportMetadata(JSON.parse(fs.readFileSync(path.resolve(args["database-export"]), "utf8")));
  const auth = JSON.parse(fs.readFileSync(path.resolve(args["auth-export"]), "utf8"));
  const emailToUID = authEmailMap(auth);
  const updates = {};
  const conflicts = [];
  let claimCount = 0;
  let unresolvedCount = 0;
  for (const [clubID, club] of Object.entries(root.clubs || {})) {
    const legacyMeetings = values(club.meetingTimes);
    for (let index = 0; index < legacyMeetings.length; index += 1) {
      const legacy = legacyMeetings[index];
      const meetingID = legacy.meetingID || legacyMeetingID(clubID, index, legacy);
      const canonical = root.clubMeetings?.[clubID]?.[meetingID];
      if (!canonical) {
        conflicts.push({ clubID, meetingID, reason: "canonical-meeting-missing" });
        continue;
      }
      if (Number(canonical.revision || 0) !== 1) {
        conflicts.push({ clubID, meetingID, reason: "canonical-meeting-edited-after-migration" });
        continue;
      }
      const emails = Array.from(new Set(values(legacy.visibleByArray).map(normalizedEmail).filter(Boolean)));
      for (const email of emails) {
        const hash = sha256(email);
        const uid = emailToUID.get(email) || null;
        if (!uid) unresolvedCount += 1;
        updates[`internal/meetingVisibilityClaims/${hash}/${meetingID}`] = {
          clubID,
          email,
          state: "active",
          lastUID: uid && canonical.visibility?.uids?.[uid] === true ? uid : null,
          updatedAt: Number(canonical.updatedAt || club.lastUpdated || 0),
        };
        updates[`internal/meetingVisibilityClaimsByMeeting/${meetingID}/${hash}`] = true;
        claimCount += 1;
      }
    }
  }
  if (conflicts.length) {
    console.log(JSON.stringify({ projectID: args.project, claimCount, unresolvedCount, conflicts }, null, 2));
    process.exitCode = 2;
    return;
  }
  updates["internal/migrations/calendar-v2/visibilityClaims"] = {
    complete: true,
    projectID: args.project,
    claimCount,
    unresolvedCount,
    completedAt: { ".sv": "timestamp" },
  };
  fs.writeFileSync(outputPath, `${JSON.stringify(updates, null, 2)}\n`, { flag: "wx", mode: 0o600 });
  console.log(JSON.stringify({
    projectID: args.project,
    updatePaths: Object.keys(updates).length,
    claimCount,
    unresolvedCount,
    conflicts: [],
  }, null, 2));
}

main();
