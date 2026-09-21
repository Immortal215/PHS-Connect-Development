"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { validateState } = require("../scripts/validate-calendar-v2-readiness");

function validState() {
  return {
    clubs: {
      robotics: {
        calendarStorageVersion: 2,
        membershipStorageVersion: 2,
        leaders: ["leader@d214.org"], members: ["leader@d214.org"], meetingTimes: [{ title: "Frozen" }],
      },
    },
    calendars: {
      robotics: {
        schemaVersion: 2,
        months: { "2026-09": { meeting: 3 } },
      },
    },
    meetings: {
      robotics: {
        meeting: {
          meetingID: "meeting", startDate: "2026-09-10",
          endDateExclusive: "2026-09-11", revision: 3,
        },
      },
    },
    clubMemberships: {
      robotics: { leader: { role: "leader", email: "leader@d214.org" } },
    },
    userClubMemberships: {
      leader: { robotics: { role: "leader" } },
    },
    checkpoints: { robotics: { complete: true, meetingCount: 1 } },
    repairs: {},
    unresolvedIdentities: { robotics: { hash: { email: "future@d214.org" } } },
    visibilityClaims: {},
    visibilityClaimsByMeeting: {},
    visibilityClaimsComplete: { complete: true, claimCount: 0 },
  };
}

test("readiness validation proves canonical conversion while legacy snapshots remain stored", () => {
  const report = validateState(validState());
  assert.equal(report.dataReady, true);
  assert.equal(report.unresolvedIdentityCount, 1);
  assert.equal(report.frozenLegacyMeetingCount, 1);
  assert.equal(Object.hasOwn(report, "legacyReadRemovalReady"), false);
});

test("readiness validation reports schema, index, audit, and reciprocal-role gaps", () => {
  const state = validState();
  state.clubs.robotics.calendarStorageVersion = 1;
  state.clubs.robotics.membershipStorageVersion = 1;
  state.calendars.robotics.schemaVersion = 1;
  state.calendars.robotics.months["2026-09"].meeting = 2;
  state.checkpoints = {};
  state.userClubMemberships.leader.robotics.role = "member";
  const report = validateState(state);
  assert.equal(report.dataReady, false);
  assert.deepEqual(report.missingSchema, ["robotics"]);
  assert.deepEqual(report.missingMembershipMarker, ["robotics"]);
  assert.equal(report.missingMeetingIndexEntries.length, 1);
  assert.equal(report.missingAuditEvidence.length, 1);
  assert.equal(report.reciprocalMembershipErrors.length, 1);
});

test("readiness validation blocks missing legacy visibility reconciliation claims", () => {
  const state = validState();
  state.clubs.robotics.meetingTimes[0].visibleByArray = ["future@d214.org"];
  state.visibilityClaimsComplete = {};
  const report = validateState(state);
  assert.equal(report.dataReady, false);
  assert.deepEqual(report.missingVisibilityClaimEvidence, ["robotics"]);
  assert.equal(report.missingVisibilityClaims.length, 1);
});
