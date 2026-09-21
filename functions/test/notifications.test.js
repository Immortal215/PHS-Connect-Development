"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  acknowledgeNotification, compareReadRevision, expirationDay, expirationKey, registrationsByToken,
  formatMeetingTime, shouldNotifyChat, stateKey,
} = require("../lib/notifications");

const profile = (style, muted = []) => ({ style, muted, registrations: [{ token: "token" }] });

test("exported meeting formatter renders timed notification ranges", () => {
  assert.equal(formatMeetingTime({
    fullDay: false,
    startUtc: Date.parse("2026-09-20T15:00:00Z") / 1000,
    endUtc: Date.parse("2026-09-20T16:30:00Z") / 1000,
    timeZone: "America/Chicago",
  }), "Sep 20, 2026, 10:00 AM – Sep 20, 2026, 11:30 AM");
});

test("exported meeting formatter renders inclusive multiday all-day range", () => {
  assert.equal(formatMeetingTime({
    fullDay: true,
    startDate: "2026-09-20",
    endDateExclusive: "2026-09-23",
  }), "2026-09-20 – 2026-09-22");
});

test("chat notification preferences preserve existing modes", () => {
  assert.equal(shouldNotifyChat(profile("all"), "general"), true);
  assert.equal(shouldNotifyChat(profile("none"), "general"), false);
  assert.equal(shouldNotifyChat(profile("mentions"), "general", false), false);
  assert.equal(shouldNotifyChat(profile("mentions"), "general", true), true);
  assert.equal(shouldNotifyChat(profile("thread", ["robotics"]), "robotics"), false);
  assert.equal(shouldNotifyChat(profile("thread", ["robotics"]), "general"), true);
  assert.equal(shouldNotifyChat({ style: "all", muted: [], registrations: [] }, "general"), false);
});

test("logical notification state keys are stable and scope-specific", () => {
  assert.equal(stateKey("chat\0a\0general"), stateKey("chat\0a\0general"));
  assert.notEqual(stateKey("chat\0a\0general"), stateKey("chat\0a\0robotics"));
});

test("read state is monotonic for chat messages and meeting revisions", () => {
  assert.ok(compareReadRevision("meeting", 8, 7) > 0);
  assert.equal(compareReadRevision("meeting", 8, 8), 0);
  assert.ok(compareReadRevision("chat", "-NxB", "-NxA") > 0);
});

function readStateAdmin(existingState) {
  let pruneQueries = 0;
  return {
    admin: {
      database() {
        return {
          ref(path) {
            if (path === "/notificationDevices/user") {
              return { get: async () => ({ val: () => null }) };
            }
            if (path === "/notificationReadState/user") {
              return {
                orderByChild() {
                  pruneQueries += 1;
                  return {
                    limitToFirst() {
                      return {
                        get: async () => ({ numChildren: () => 0 }),
                      };
                    },
                  };
                },
              };
            }
            if (path.startsWith("/notificationReadState/user/")) {
              return {
                async transaction(update) {
                  const value = update(existingState);
                  return {
                    committed: value !== undefined,
                    snapshot: { val: () => value === undefined ? existingState : value },
                  };
                },
              };
            }
            throw new Error(`Unexpected path: ${path}`);
          },
        };
      },
    },
    pruneQueries: () => pruneQueries,
  };
}

test("updating an existing read scope skips the collection-wide prune query", async () => {
  const fake = readStateAdmin({
    type: "chat", revision: "-NxA", chatID: "chat", threadName: "general",
    messageID: "-NxA", seenAt: 1,
  });
  await acknowledgeNotification(fake.admin, { uid: "user" }, {
    type: "chat", chatID: "chat", threadName: "general", messageID: "-NxB",
  });
  assert.equal(fake.pruneQueries(), 0);
});

test("creating a read scope runs the bounded prune check", async () => {
  const fake = readStateAdmin(null);
  await acknowledgeNotification(fake.admin, { uid: "user" }, {
    type: "meeting", meetingID: "meeting", revision: 1,
  });
  assert.equal(fake.pruneQueries(), 1);
});

test("multi-device fanout deduplicates tokens without losing installation cleanup metadata", () => {
  const grouped = registrationsByToken([
    { uid: "one", installationID: "phone", token: "shared" },
    { uid: "one", installationID: "tablet", token: "tablet" },
    { uid: "old", installationID: "old-phone", token: "shared" },
  ]);
  assert.deepEqual(Array.from(grouped.keys()), ["shared", "tablet"]);
  assert.equal(grouped.get("shared").length, 2);
});

test("device-expiration index is deterministic and bounded by day", () => {
  assert.equal(expirationDay(Date.parse("2026-09-11T00:00:00Z")), "2026-11-10");
  assert.equal(expirationKey("user", "installation"), expirationKey("user", "installation"));
  assert.notEqual(expirationKey("user", "phone"), expirationKey("user", "tablet"));
});

function reactionAdmin({ style = "all", muted = [], seenAt = 0 } = {}) {
  const sent = [];
  const values = {
    "/chats/chat/messages/old-message/sender": "receiver",
    "/chats/chat/messages/old-message/threadName": "robotics",
    "/chats/chat/clubID": "club",
    "/clubMemberships/club/receiver/role": "member",
    "/clubs/club/chatEnabled": true,
    "/clubs/club/name": "Club",
    "/users/reactor/userName": "Reactor",
    "/users/receiver/chatNotifStyles/chat": style,
    "/users/receiver/mutedThreadsByChat/chat": muted,
    "/notificationDevices/receiver": { phone: { token: "token" } },
    [`/notificationReadState/receiver/${stateKey("chat\0chat\0robotics")}`]: {
      type: "chat", revision: "old-message", seenAt,
    },
  };
  return {
    sent,
    database: () => ({ ref: (path = "") => ({
      get: async () => ({ val: () => values[path] ?? null }),
      update: async (updates) => { for (const [key, value] of Object.entries(updates)) values[`/${key}`] = value; },
    }) }),
    messaging: () => ({ sendEachForMulticast: async (payload) => {
      sent.push(payload);
      return { successCount: 1, failureCount: 0, responses: [{ success: true }] };
    } }),
  };
}

const reactionEvent = (time = "2026-09-21T12:00:00.000Z", id = "event-one") => ({
  id, time, params: { chatID: "chat", messageID: "old-message", emoji: "👍" },
  data: { before: { val: () => [] }, after: { val: () => ["reactor"] } },
});
const { reactionDescriptor, reactionTimestamp, sendReactionNotification } = require("../lib/notifications");

test("reaction handler honors all, thread, none and mentions preferences", async () => {
  for (const [style, muted, count] of [
    ["all", ["robotics"], 1], ["thread", ["robotics"], 0],
    ["thread", ["another"], 1], ["none", [], 0], ["mentions", [], 0],
  ]) {
    const admin = reactionAdmin({ style, muted });
    await sendReactionNotification(admin, reactionEvent());
    assert.equal(admin.sent.length, count, style);
  }
});

test("later reaction on an already-read message is delivered but already-seen delayed reaction is suppressed", async () => {
  const occurredAt = Date.parse(reactionEvent().time);
  const beforeReaction = reactionAdmin({ seenAt: occurredAt - 1 });
  await sendReactionNotification(beforeReaction, reactionEvent());
  assert.equal(beforeReaction.sent.length, 1);
  assert.equal(reactionTimestamp(beforeReaction.sent[0].data.readRevision), occurredAt);
  const afterReaction = reactionAdmin({ seenAt: occurredAt + 1 });
  await sendReactionNotification(afterReaction, reactionEvent());
  assert.equal(afterReaction.sent.length, 0);
});

test("reaction identity is stable on retries and monotonic across event times", () => {
  const descriptor = (event) => reactionDescriptor("chat", "robotics", "old-message", event);
  const first = descriptor(reactionEvent());
  assert.deepEqual(descriptor(reactionEvent()), first);
  assert.notEqual(descriptor(reactionEvent(undefined, "other-event")).revision, first.revision);
  assert.ok(descriptor(reactionEvent("2026-09-21T12:00:00.001Z")).revision > first.revision);
  assert.throws(() => descriptor(reactionEvent("bad-time")));
});

test("seeing reactions advances seenAt even with the same or older message cursor", async () => {
  for (const messageID of ["-NxB", "-NxA"]) {
    const fake = readStateAdmin({ type: "chat", revision: "-NxB", messageID: "-NxB", seenAt: 1 });
    const result = await acknowledgeNotification(fake.admin, { uid: "user" }, {
      type: "chat", chatID: "chat", threadName: "general", messageID,
    });
    assert.equal(result.state.revision, "-NxB");
    assert.ok(result.state.seenAt > 1);
  }
});
