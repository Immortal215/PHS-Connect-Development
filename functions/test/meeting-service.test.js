"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");
const { deleteMeetings, saveMeetings, syncClubCalendar } = require("../lib/meeting-service");

function testAdmin(initialValues = {}) {
  const values = structuredClone(initialValues);
  const reads = [];
  const writes = [];
  let nextMeetingID = 1;
  const parts = (path) => String(path || "").split("/").filter(Boolean);
  const valueAt = (path) => parts(path).reduce(
    (value, part) => value == null ? undefined : value[part], values
  );
  const setValue = (path, value) => {
    const keys = parts(path);
    let parent = values;
    for (const key of keys.slice(0, -1)) parent = parent[key] ||= {};
    const key = keys.at(-1);
    if (value == null) delete parent[key];
    else parent[key] = value;
  };
  const snapshot = (value) => ({
    val: () => value ?? null,
    exists: () => value != null,
    child: (key) => snapshot(value?.[key]),
  });
  const db = {
    ref(path = "") {
      let after, target, limit;
      return {
        orderByKey() { return this; },
        startAfter(value) { after = value; return this; },
        endAt(value) { target = value; return this; },
        limitToFirst(value) { limit = value; return this; },
        async get() {
          reads.push(path);
          let value = valueAt(path);
          if (after !== undefined || target !== undefined || limit !== undefined) {
            value = Object.fromEntries(Object.entries(value || {}).sort(([a], [b]) => a.localeCompare(b))
              .filter(([key]) => (after === undefined || key > after) && (target === undefined || key <= target))
              .slice(0, limit));
          }
          return snapshot(value);
        },
        push: () => ({ key: `meeting-${nextMeetingID++}` }),
        async transaction(transform) {
          const next = transform(valueAt(path));
          if (next === undefined) {
            return { committed: false, snapshot: snapshot(valueAt(path)) };
          }
          setValue(path, next);
          return { committed: true, snapshot: snapshot(next) };
        },
        async update(nextUpdates) {
          writes.push(structuredClone(nextUpdates));
          for (const [updatePath, value] of Object.entries(nextUpdates)) {
            setValue(updatePath, value);
          }
        },
      };
    },
  };
  return {
    auth: () => ({
      async getUserByEmail(email) {
        if (email === "member@stu.d214.org") {
          return { uid: "member", email, emailVerified: true, disabled: false };
        }
        const error = new Error("missing");
        error.code = "auth/user-not-found";
        throw error;
      },
    }),
    database: () => db,
    values,
    reads,
    writes,
  };
}

function initialValues(meeting = null) {
  return {
    clubCalendars: {
      robotics: { schemaVersion: 2, sequence: 0, latestChange: "" },
    },
    clubMemberships: {
      robotics: {
        leader: { role: "leader", email: "leader@d214.org" },
      },
    },
    clubMeetings: meeting ? { robotics: { [meeting.meetingID]: meeting } } : {},
  };
}

function allDayMeeting(overrides = {}) {
  return {
    clubID: "robotics",
    title: "Planning",
    description: "",
    location: "Room 1",
    fullDay: true,
    startDate: "2026-09-20",
    endDateExclusive: "2026-09-21",
    visibilityMode: "uids",
    visibilityEmails: ["MEMBER@stu.d214.org"],
    ...overrides,
  };
}

const leader = {
  uid: "leader", email: "leader@d214.org", email_verified: true,
};

test("new meeting save resolves visibility emails through the runtime crypto import", async () => {
  const admin = testAdmin(initialValues());

  const result = await saveMeetings(admin, leader, {
    operationID: "create-op-1",
    meetings: [allDayMeeting()],
  });

  assert.equal(result.meetings.length, 1);
  assert.equal(result.meetings[0].meetingID, "meeting-1");
  assert.deepEqual(result.meetings[0].visibility, {
    mode: "uids", uids: { member: true },
  });
  const hash = crypto.createHash("sha256").update("member@stu.d214.org").digest("hex");
  assert.equal(
    admin.values.internal.meetingVisibilityClaims[hash]["meeting-1"].lastUID,
    "member"
  );
  assert.equal(admin.values.internal.meetingOperations["create-op-1"].status, "complete");
  assert.equal(admin.values.internal.meetingNotificationJobs["create-op-1"].kind, "created");
});

test("meeting edit executes the saved-meeting entry point", async () => {
  const existing = {
    ...allDayMeeting({
      meetingID: "existing", visibilityMode: undefined, visibilityEmails: undefined,
      visibility: { mode: "public" },
    }),
    revision: 1,
    createdAt: 100,
    updatedAt: 100,
    cancelled: false,
  };
  const admin = testAdmin(initialValues(existing));

  const result = await saveMeetings(admin, leader, {
    operationID: "update-op-1",
    replacingClubID: "robotics",
    replacingMeetingID: "existing",
    expectedRevision: 1,
    meetings: [allDayMeeting({ title: "Updated planning", visibilityMode: "public", visibilityEmails: [] })],
  });

  assert.equal(result.meetings[0].meetingID, "existing");
  assert.equal(result.meetings[0].title, "Updated planning");
  assert.equal(result.meetings[0].revision, 2);
  assert.equal(admin.values.internal.meetingNotificationJobs["update-op-1"].kind, "updated");
});

test("meeting delete executes the deletion entry point", async () => {
  const existing = {
    ...allDayMeeting({
      meetingID: "existing", visibilityMode: undefined, visibilityEmails: undefined,
      visibility: { mode: "public" },
    }),
    revision: 2,
    createdAt: 100,
    updatedAt: 200,
    cancelled: false,
  };
  const admin = testAdmin(initialValues(existing));

  const result = await deleteMeetings(admin, leader, {
    operationID: "delete-op-1",
    clubID: "robotics",
    meetingID: "existing",
    includingFuture: false,
  });

  assert.deepEqual(result, { deleted: ["existing"] });
  assert.equal(admin.values.clubMeetings.robotics.existing.cancelled, true);
  assert.equal(admin.values.clubMeetings.robotics.existing.revision, 3);
  assert.equal(admin.values.internal.meetingOperations["delete-op-1"].status, "complete");
});

for (const kind of ["save", "delete"]) {
  test(`${kind} response-loss replay returns the canonical result without another commit`, async () => {
    const existing = { ...allDayMeeting({ meetingID: "existing", visibility: { mode: "public" } }), revision: 1, cancelled: false };
    const admin = testAdmin(initialValues(kind === "delete" ? existing : null));
    const body = kind === "save"
      ? { operationID: "lost-save-response", meetings: [allDayMeeting()] }
      : { operationID: "lost-delete-response", clubID: "robotics", meetingID: "existing" };
    const mutate = kind === "save" ? saveMeetings : deleteMeetings;
    const lostResponse = await mutate(admin, leader, body);
    const afterCommit = structuredClone(admin.values);
    const retry = await mutate(admin, leader, body);
    assert.deepEqual(retry, lostResponse);
    assert.deepEqual(admin.values, afterCommit);
    assert.equal(admin.values.clubCalendars.robotics.sequence, 1);
  });
}

test("edit response-loss replay does not fail the old revision or increment it twice", async () => {
  const existing = { ...allDayMeeting({ meetingID: "existing", visibility: { mode: "public" } }), revision: 1, cancelled: false };
  const admin = testAdmin(initialValues(existing));
  const body = { operationID: "lost-edit-response", replacingClubID: "robotics", replacingMeetingID: "existing", expectedRevision: 1,
    meetings: [allDayMeeting({ title: "Edited", visibilityMode: "public", visibilityEmails: [] })] };
  const result = await saveMeetings(admin, leader, body);
  const afterCommit = structuredClone(admin.values);
  assert.deepEqual(await saveMeetings(admin, leader, body), result);
  assert.deepEqual(admin.values, afterCommit);
});

test("save, edit, and delete publish one club cursor without member-count writes", async () => {
  const writeCounts = [];
  for (const count of [1, 1000]) {
    const seed = initialValues();
    seed.userClubMemberships = {};
    for (let index = 0; index < count; index++) {
      const uid = `member-${index}`;
      const membership = { role: "member", email: `${uid}@d214.org`, calendarCursor: "legacy-cursor" };
      seed.clubMemberships.robotics[uid] = membership;
      seed.userClubMemberships[uid] = { robotics: membership };
    }
    const admin = testAdmin(seed);
    const member = { uid: "member-0", email: "member-0@d214.org", email_verified: true };
    const query = { clubID: "robotics", start: "2026-09-01", end: "2026-10-01" };
    const input = allDayMeeting({ visibilityMode: "public", visibilityEmails: [] });
    const created = await saveMeetings(admin, leader, { operationID: "cursor-create", meetings: [input] });
    const meetingID = created.meetings[0].meetingID;
    const first = await syncClubCalendar(admin, member, query);
    assert.equal(first.mode, "snapshot");
    assert.equal(first.meetings[0].meetingID, meetingID);
    await saveMeetings(admin, leader, {
      operationID: "cursor-edit", replacingClubID: "robotics", replacingMeetingID: meetingID,
      expectedRevision: 1, meetings: [{ ...input, title: "Edited" }],
    });
    const edited = await syncClubCalendar(admin, member, { ...query, after: first.latestChange });
    assert.equal(edited.mode, "delta");
    assert.equal(edited.changes[0].meeting.title, "Edited");
    await deleteMeetings(admin, leader, { operationID: "cursor-delete", clubID: "robotics", meetingID });
    const cancelled = await syncClubCalendar(admin, member, { ...query, after: edited.nextCursor });
    assert.equal(cancelled.changes[0].operation, "cancel");
    const page = await syncClubCalendar(admin, member, {
      ...query, after: first.latestChange, target: cancelled.latestChange, limit: 1,
    });
    assert.equal(page.hasMore, true);
    assert.equal(page.nextCursor, edited.nextCursor);
    const finalPage = await syncClubCalendar(admin, member, {
      ...query, after: page.nextCursor, target: page.target, limit: 1,
    });
    assert.equal(finalPage.hasMore, false);
    assert.equal(finalPage.nextCursor, cancelled.nextCursor);
    const readCount = admin.reads.length;
    const unchanged = await syncClubCalendar(admin, member, { ...query, after: cancelled.nextCursor });
    assert.deepEqual(unchanged.changes, []);
    assert.equal(unchanged.hasMore, false);
    assert.equal(admin.reads.slice(readCount).some((path) => path.startsWith("/clubMeetings/")), false);
    assert.deepEqual(admin.values.userClubMemberships, seed.userClubMemberships);
    // Saves still read the roster for RSVP visibility invalidation; cursor publication adds no read.
    assert.equal(admin.reads.filter((path) => path === "/clubMemberships/robotics").length, 2);
    assert.equal(admin.writes.some((batch) => Object.keys(batch).some((key) => key.startsWith("userClubMemberships/"))), false);
    assert.equal(admin.values.clubCalendars.robotics.latestChange, "0000000000000003");
    writeCounts.push(admin.writes.map((batch) => Object.keys(batch).length));
    delete admin.values.clubMemberships.robotics[member.uid];
    await assert.rejects(syncClubCalendar(admin, member, query), { status: 403 });
  }
  assert.deepEqual(writeCounts[0], writeCounts[1]);
});
