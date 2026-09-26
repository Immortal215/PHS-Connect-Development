"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const {
  assertFails, assertSucceeds, initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { get, ref, set } = require("firebase/database");

test("claims replace the old admin email list without blocking current members", async () => {
  const environment = await initializeTestEnvironment({
    projectId: "demo-phs-admin-claim-rules",
    database: {
      rules: fs.readFileSync(path.resolve(__dirname, "../../database.rules.json"), "utf8"),
    },
  });
  try {
    await environment.withSecurityRulesDisabled(async (context) => {
      await set(ref(context.database()), {
        clubs: { "11": {
          clubID: "11", name: "Example", chatEnabled: true, lastUpdated: 1,
          meetingTimes: [{ meetingID: "legacy" }],
        } },
        clubMemberships: { "11": {
          leader: { role: "leader", email: "leader@d214.org" },
          member: { role: "member", email: "member@d214.org" },
        } },
        clubCalendars: { "11": { latestChange: "cursor", changes: { secret: true } } },
        clubMeetings: { "11": { m1: { meetingID: "m1" } } },
        chats: { chat: { clubID: "11" } },
      });
    });

    const claimed = environment.authenticatedContext("new-admin", {
      email: "new.admin@gmail.com", email_verified: true, phsSuperAdmin: true,
    }).database();
    const frank = environment.authenticatedContext("frank", {
      email: "frank.mirandola@d214.org", email_verified: true,
    }).database();
    const removed = environment.authenticatedContext("removed", {
      email: "sharul.shah2008@gmail.com", email_verified: true,
    }).database();
    const leader = environment.authenticatedContext("leader", {
      email: "leader@d214.org", email_verified: true,
    }).database();
    const member = environment.authenticatedContext("member", {
      email: "member@d214.org", email_verified: true,
    }).database();

    await assertSucceeds(set(ref(claimed, "clubs/11/chatEnabled"), false));
    await assertSucceeds(set(ref(claimed, "clubs/11/announcements/a"), { title: "Admin" }));
    await assertSucceeds(set(ref(claimed, "chats/chat/messages/a"), {
      threadName: "announcements", message: "Admin", sender: "new-admin",
    }));
    await assertSucceeds(get(ref(claimed, "clubCalendars/11/latestChange")));

    for (const unclaimed of [frank, removed]) {
      await assertFails(set(ref(unclaimed, "clubs/11/chatEnabled"), true));
      await assertFails(set(ref(unclaimed, "clubs/11/announcements/old-admin"), { title: "No" }));
      await assertFails(set(ref(unclaimed, "chats/chat/messages/old-admin"), {
        threadName: "announcements", message: "No", sender: "old-admin",
      }));
      await assertFails(get(ref(unclaimed, "clubCalendars/11/latestChange")));
    }

    await assertSucceeds(set(ref(leader, "clubs/11/chatEnabled"), true));
    await assertSucceeds(set(ref(member, "chats/chat/messages/general"), {
      threadName: "general", message: "Hello", sender: "member",
    }));
    await assertFails(set(ref(member, "clubs/11/announcements/member"), { title: "No" }));
    await assertSucceeds(get(ref(member, "clubCalendars/11/latestChange")));
    await assertFails(get(ref(member, "clubCalendars/11/changes")));

    for (const client of [claimed, leader, member, frank]) {
      await assertFails(set(ref(client, "clubs/11/meetingTimes"), []));
      await assertFails(set(ref(client, "clubMeetings/11/m1/title"), "Bypass"));
      await assertFails(set(ref(client, "clubMemberships/11/frank"), {
        role: "leader", email: "frank.mirandola@d214.org",
      }));
    }
    const publicClub = await assertSucceeds(get(ref(environment.unauthenticatedContext().database(), "clubs/11")));
    assert.equal(publicClub.val().meetingTimes[0].meetingID, "legacy");
  } finally {
    await environment.cleanup();
  }
});
