"use strict";

const fs = require("fs");
const path = require("path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  assertFails, assertSucceeds, initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { get, orderByChild, query, ref, set, update } = require("firebase/database");

let environment;

test.before(async () => {
  const rulesPath = path.resolve(__dirname, "../../database.rules.json");
  environment = await initializeTestEnvironment({
    projectId: "phs-connect-local-test",
    database: { rules: fs.readFileSync(rulesPath, "utf8") },
  });
  await environment.withSecurityRulesDisabled(async (context) => {
    await set(ref(context.database()), {
      clubs: { robotics: {
        clubID: "robotics", name: "Robotics", lastUpdated: 10, chatEnabled: true,
        leaders: ["leader@d214.org"], members: ["member@d214.org"],
        meetingTimes: [{ meetingID: "legacy", title: "Readable" }],
      } },
      clubMemberships: {
        robotics: {
          leader: { role: "leader", email: "leader@d214.org" },
          member: { role: "member", email: "member@d214.org" },
        },
      },
      userClubMemberships: {
        leader: { robotics: { role: "leader" } }, member: { robotics: { role: "member" } },
      },
      clubCalendars: { robotics: { latestChange: "0000000000000007", changes: { secret: true } } },
      clubMeetings: { robotics: { secret: { meetingID: "secret", seriesID: "series", title: "Private" } } },
      meetingRSVPs: { secret: { member: { status: "going" } } },
      chats: { chat: { clubID: "robotics" } },
    });
  });
});

test.after(async () => { await environment?.cleanup(); });
test.beforeEach(async () => { await environment.clearDatabase(); });

async function seed() {
  await environment.withSecurityRulesDisabled(async (context) => {
    await set(ref(context.database()), {
      clubs: { robotics: { clubID: "robotics", name: "Robotics", lastUpdated: 10, chatEnabled: true } },
      clubMemberships: { robotics: { leader: { role: "leader" }, member: { role: "member" } } },
      userClubMemberships: { leader: { robotics: { role: "leader" } }, member: { robotics: { role: "member" } } },
      clubCalendars: { robotics: { latestChange: "0000000000000007", changes: { secret: true } } },
      clubMeetings: { robotics: { secret: { meetingID: "secret", seriesID: "series", title: "Private" } } },
      meetingRSVPs: { secret: { member: { status: "going" } } },
      chats: { chat: { clubID: "robotics" } },
    });
  });
}

test("public discovery query works and is indexed", async () => {
  await seed();
  const guest = environment.unauthenticatedContext().database();
  await assertSucceeds(get(query(ref(guest, "clubs"), orderByChild("lastUpdated"))));
  const rules = JSON.parse(fs.readFileSync(path.resolve(__dirname, "../../database.rules.json"), "utf8"));
  assert.ok(rules.rules.clubs[".indexOn"].includes("lastUpdated"));
  assert.ok(rules.rules.clubMeetings.$club_id[".indexOn"].includes("seriesID"));
});

test("private calendar, RSVP, device, and internal nodes are never client-readable", async () => {
  await seed();
  const member = environment.authenticatedContext("member", { email: "member@d214.org" }).database();
  for (const location of [
    "clubMeetings/robotics", "clubCalendars/robotics", "meetingRSVPs/secret",
    "notificationDevices/member", "calendarSubscriptions/member", "internal",
  ]) await assertFails(get(ref(member, location)));
  await assertSucceeds(get(ref(member, "userClubMemberships/member")));
  await assertFails(get(ref(member, "userClubMemberships/leader")));
});

test("clients cannot self-approve membership or use legacy meeting and roster writes", async () => {
  await seed();
  const outsider = environment.authenticatedContext("outsider", { email: "outsider@d214.org" }).database();
  const leader = environment.authenticatedContext("leader", { email: "leader@d214.org" }).database();
  await assertFails(set(ref(outsider, "clubMemberships/robotics/outsider"), { role: "leader" }));
  await assertFails(set(ref(leader, "clubs/robotics/meetingTimes"), [{ title: "Bypass" }]));
  await assertFails(set(ref(leader, "clubs/robotics/members"), ["outsider@d214.org"]));
});

test("legacy club projections remain publicly readable but read-only", async () => {
  await seed();
  await environment.withSecurityRulesDisabled(async (context) => {
    await update(ref(context.database(), "clubs/robotics"), {
      leaders: ["leader@d214.org"], members: ["member@d214.org"],
      meetingTimes: [{ meetingID: "legacy", title: "Readable" }],
    });
  });
  const guest = environment.unauthenticatedContext().database();
  const club = (await assertSucceeds(get(ref(guest, "clubs/robotics")))).val();
  assert.equal(club.meetingTimes[0].title, "Readable");
  assert.deepEqual(club.members, ["member@d214.org"]);
  await assertFails(set(ref(guest, "clubs/robotics/meetingTimes"), []));
});

test("profile writes remain available but legacy notification tokens are denied", async () => {
  await seed();
  const member = environment.authenticatedContext("member", { email: "member@d214.org" }).database();
  await assertSucceeds(update(ref(member, "users/member"), {
    userID: "member",
    userEmail: "member@d214.org",
    userImage: "",
    userName: "Member",
    favoritedClubs: ["robotics"],
  }));
  await assertSucceeds(set(ref(member, "users/member/chatNotifStyles/chat"), "thread"));
  await assertFails(set(ref(member, "users/member/fcmToken"), "legacy-token"));
  await assertFails(set(ref(member, "users/member/userEmail"), "someone-else@d214.org"));
});

test("member chat behavior remains available while announcements require a leader", async () => {
  await seed();
  const member = environment.authenticatedContext("member", { email: "member@d214.org" }).database();
  const leader = environment.authenticatedContext("leader", { email: "leader@d214.org" }).database();
  const outsider = environment.authenticatedContext("outsider", { email: "outsider@d214.org" }).database();
  await assertSucceeds(set(ref(member, "chats/chat/messages/general"), {
    sender: "member", message: "Hello", threadName: "general", date: 10,
  }));
  await assertFails(set(ref(outsider, "chats/chat/messages/outside"), {
    sender: "outsider", message: "No", threadName: "general", date: 11,
  }));
  await assertFails(set(ref(member, "clubs/robotics/announcements/a"), { title: "No" }));
  await assertSucceeds(set(ref(leader, "clubs/robotics/announcements/a"), { title: "Yes" }));
});

test("super administrators can manage every club through scoped paths without reopening legacy writes", async () => {
  await seed();
  const admin = environment.authenticatedContext("admin", {
    email: "sharul.shah2008@gmail.com",
  }).database();

  await assertSucceeds(update(ref(admin, "clubs/robotics"), {
    chatEnabled: false,
    locationInSchoolCoordinates: [12, 34],
    lastUpdated: 20,
  }));
  await assertSucceeds(set(ref(admin, "clubs/robotics/announcements/admin-note"), {
    clubID: "robotics", title: "Admin announcement",
  }));
  await assertSucceeds(set(ref(admin, "clubs/robotics/chatIDs"), ["chat"]));
  await assertSucceeds(set(ref(admin, "chats/chat/messages/admin-announcement"), {
    sender: "admin", message: "Important", threadName: "announcements", date: 20,
  }));

  await assertFails(set(ref(admin, "clubs/robotics/meetingTimes"), [{ title: "Bypass" }]));
  await assertFails(set(ref(admin, "clubs/robotics/leaders"), ["admin@gmail.com"]));
  await assertFails(set(ref(admin, "clubMeetings/robotics/secret/title"), "Bypass"));
  await assertFails(set(ref(admin, "clubMemberships/robotics/admin"), { role: "leader" }));

  assert.equal((await assertSucceeds(get(
    ref(admin, "clubCalendars/robotics/latestChange")
  ))).val(), "0000000000000007");
  await assertFails(get(ref(admin, "clubCalendars/robotics")));
});

test("only current verified members and leaders can read the calendar cursor scalar", async () => {
  await seed();
  await environment.withSecurityRulesDisabled(async (context) => {
    await update(ref(context.database(), "clubMemberships/robotics"), {
      member: { role: "member", email: "member@d214.org" },
      leader: { role: "leader", email: "leader@d214.org" },
      pending: { role: "pending", email: "pending@d214.org" },
    });
  });
  for (const uid of ["member", "leader"]) {
    const db = environment.authenticatedContext(uid, {
      email: `${uid.toUpperCase()}@D214.ORG`, email_verified: true,
    }).database();
    assert.equal((await assertSucceeds(get(ref(db, "clubCalendars/robotics/latestChange")))).val(), "0000000000000007");
    for (const location of ["clubCalendars", "clubCalendars/robotics", "clubCalendars/robotics/changes", "clubMeetings/robotics"]) {
      await assertFails(get(ref(db, location)));
    }
    await assertFails(set(ref(db, "clubCalendars/robotics/latestChange"), "forged"));
    await assertFails(get(ref(db, "clubCalendars/unjoined/latestChange")));
  }
  const denied = [
    environment.unauthenticatedContext(),
    environment.authenticatedContext("outsider", { email: "outsider@d214.org", email_verified: true }),
    environment.authenticatedContext("pending", { email: "pending@d214.org", email_verified: true }),
    environment.authenticatedContext("member", { email: "member@d214.org", email_verified: false }),
    environment.authenticatedContext("member", { email: "changed@d214.org", email_verified: true }),
    environment.authenticatedContext("member", { email_verified: true }),
  ];
  for (const context of denied) {
    await assertFails(get(ref(context.database(), "clubCalendars/robotics/latestChange")));
  }
  await environment.withSecurityRulesDisabled(async (context) => {
    await set(ref(context.database(), "clubMemberships/robotics/member"), null);
  });
  const removed = environment.authenticatedContext("member", {
    email: "member@d214.org", email_verified: true,
  }).database();
  // The stale userClubMemberships mirror must not authorize reads after canonical revocation.
  await assertFails(get(ref(removed, "clubCalendars/robotics/latestChange")));
});
