"use strict";

const { onRequest } = require("firebase-functions/v2/https");
const { onValueCreated, onValueDeleted, onValueWritten } = require("firebase-functions/v2/database");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const functionsV1 = require("firebase-functions/v1");
const { apiHandler, calendarFeedHandler } = require("./lib/api");
const { REGION } = require("./lib/constants");
const { createAdminServices } = require("./lib/firebase-admin-services");
const {
  appendLeaderAccessRevision, auditAuthUser, cleanupCompletedClubOperations,
  userRSVPInvalidationUpdates,
} = require("./lib/membership-service");
const {
  cleanupCompletedMeetingRecords, compactCalendarChanges, completeMeetingNotificationJob,
  handleDeletedClub, readMeeting,
} = require("./lib/meeting-service");
const {
  alreadyRead, chatRecipients, expirationKey, formatMeetingTime, meetingRecipientRegistrations,
  retryNotificationDeliveries, sendReactionNotification, sendToRegistrations, stateKey,
} = require("./lib/notifications");

const admin = createAdminServices();

exports.phsApi = onRequest({ region: REGION, cors: false }, apiHandler(admin));
exports.calendarFeed = onRequest({ region: REGION, cors: false }, calendarFeedHandler(admin));

exports.compactCalendarChangeLog = onValueWritten({
  ref: "/clubCalendars/{clubID}/latestChange", region: REGION, retry: true,
}, async (event) => {
  if (event.data.before.val() === event.data.after.val() || !event.data.after.exists()) return;
  await compactCalendarChanges(admin, event.params.clubID);
});

exports.cleanupDeletedClub = onValueDeleted({
  ref: "/clubs/{clubID}", region: REGION, retry: true,
}, async (event) => {
  await handleDeletedClub(admin, event.params.clubID, event.data.val() || {});
});

function previewText(value) {
  const text = String(value || "");
  return text.length ? text.slice(0, 80) : "(attachment)";
}

function chatDescriptor(chatID, threadName, messageID) {
  return {
    type: "chat", scope: `chat\u0000${chatID}\u0000${threadName}`,
    revision: messageID, chatID, threadName, messageID,
  };
}

async function filterUnread(db, candidates, descriptor) {
  const values = await Promise.all(candidates.map(async (candidate) => ({
    candidate, read: await alreadyRead(db, candidate.uid, descriptor),
  })));
  return values.filter((value) => !value.read).map((value) => value.candidate);
}

exports.sendChatNotification = onValueCreated({
  ref: "/chats/{chatID}/messages/{messageID}", region: REGION, retry: true,
}, async (event) => {
  const message = event.data.val() || {};
  const { chatID, messageID } = event.params;
  const senderUID = String(message.sender || "");
  const threadName = String(message.threadName || "general");
  if (!senderUID) return;
  const db = admin.database();
  const clubID = (await db.ref(`/chats/${chatID}/clubID`).get()).val();
  if (!clubID) return;
  const [chatEnabled, clubName, senderName] = await Promise.all([
    db.ref(`/clubs/${clubID}/chatEnabled`).get(),
    db.ref(`/clubs/${clubID}/name`).get(),
    db.ref(`/users/${senderUID}/userName`).get(),
  ]);
  if (chatEnabled.val() === false) return;
  const candidates = await chatRecipients(db, {
    clubID, chatID, senderUID, threadName, isMention: false,
  });
  const descriptor = chatDescriptor(chatID, threadName, messageID);
  const unread = await filterUnread(db, candidates, descriptor);
  const registrations = unread.flatMap(({ profile }) => profile.registrations);
  if (!registrations.length) return;
  const sender = senderName.val() || "Someone";
  const club = clubName.val() || "New Message";
  const preview = previewText(message.message);
  return sendToRegistrations(admin, registrations, {
    notification: {
      title: `${sender} • ${club}`,
      body: threadName === "general" ? preview : `[${threadName}] ${preview}`,
    },
    data: {
      type: "message", chatID, messageID, threadName, senderUID,
      clubID, clubName: club, senderName: sender, preview,
      logicalScope: stateKey(descriptor.scope), readRevision: messageID,
    },
    apns: { headers: { "apns-collapse-id": stateKey(descriptor.scope) }, payload: { aps: { threadId: `chat-${chatID}` } } },
  }, { deliveryID: `chat-${event.id}`, descriptor });
});

exports.sendReactionNotification = onValueWritten({
  ref: "/chats/{chatID}/messages/{messageID}/reactions/{emoji}", region: REGION, retry: true,
}, async (event) => {
  return sendReactionNotification(admin, event);
});

exports.sendMeetingNotification = onValueCreated({
  ref: "/internal/meetingNotificationJobs/{jobID}", region: REGION, retry: true,
}, async (event) => {
  const jobRef = event.data.ref;
  const owner = event.id;
  const now = Date.now();
  const lease = await jobRef.transaction((current) => {
    if (!current || current.status === "complete") return;
    if (current.status === "processing" && current.leaseExpiresAt > now) return;
    return { ...current, status: "processing", owner, leaseExpiresAt: now + 120000 };
  }, undefined, false);
  if (!lease.committed || lease.snapshot.val()?.owner !== owner) return;
  const job = lease.snapshot.val();
  try {
    const db = admin.database();
    const meeting = await readMeeting(db, job.clubID, job.meetingID);
    if (!meeting || meeting.cancelled) {
      await completeMeetingNotificationJob(db, event.params.jobID, admin.serverTimestamp);
      return;
    }
    const clubName = (await db.ref(`/clubs/${job.clubID}/name`).get()).val() || "Meeting Update";
    const registrations = await meetingRecipientRegistrations(db, meeting);
    const byUID = new Map();
    for (const registration of registrations) {
      if (!byUID.has(registration.uid)) byUID.set(registration.uid, []);
      byUID.get(registration.uid).push(registration);
    }
    const descriptor = {
      type: "meeting", scope: `meeting\u0000${meeting.meetingID}`,
      revision: meeting.revision, meetingID: meeting.meetingID,
    };
    const unread = await filterUnread(db, Array.from(byUID, ([uid, items]) => ({ uid, items })), descriptor);
    const recipients = unread.flatMap((item) => item.items);
    const action = job.kind === "updated" ? "Updated" : "Created";
    const eventType = job.repeating ? "repeating event" : "meeting";
    if (recipients.length) await sendToRegistrations(admin, recipients, {
      notification: {
        title: clubName,
        body: `${action} ${eventType}: ${meeting.title || "Club Meeting"}\n${formatMeetingTime(meeting)}`,
      },
      data: {
        type: "meeting", clubID: job.clubID, clubName,
        meetingID: meeting.meetingID, meetingTitle: meeting.title || "",
        meetingRevision: String(meeting.revision),
        logicalScope: stateKey(descriptor.scope), readRevision: String(meeting.revision),
      },
      apns: { headers: { "apns-collapse-id": stateKey(descriptor.scope) }, payload: { aps: { threadId: `meeting-${meeting.meetingID}` } } },
    }, { deliveryID: `meeting-${event.params.jobID}`, descriptor });
    await completeMeetingNotificationJob(db, event.params.jobID, admin.serverTimestamp);
  } catch (error) {
    console.error("Meeting notification delivery failed", { jobID: event.params.jobID, error });
    await jobRef.update({ status: "retry", lastErrorAt: admin.serverTimestamp, owner: null, leaseExpiresAt: null });
    throw error;
  }
});

exports.cleanupStaleNotificationDevices = onSchedule({
  schedule: "every day 03:17", timeZone: "America/Chicago", region: REGION,
}, async () => {
  const today = new Date().toISOString().slice(0, 10);
  const expirationRef = admin.database().ref("/internal/notificationDeviceExpirations");
  const deliveryExpirationRef = admin.database().ref("/internal/notificationDeliveryExpirations");
  const [snapshot, deliverySnapshot] = await Promise.all([
    expirationRef.orderByKey().endAt(today).limitToFirst(8).get(),
    deliveryExpirationRef.orderByKey().endAt(today).limitToFirst(8).get(),
  ]);
  const removals = {};
  for (const [day, entries] of Object.entries(snapshot.val() || {})) {
    for (const value of Object.values(entries || {})) {
      const uid = value?.uid;
      const installationID = value?.installationID;
      if (!uid || !installationID) continue;
      removals[`notificationDevices/${uid}/${installationID}`] = null;
      removals[`internal/notificationInstallationOwners/${installationID}`] = null;
    }
    removals[`internal/notificationDeviceExpirations/${day}`] = null;
  }
  for (const [day, deliveries] of Object.entries(deliverySnapshot.val() || {})) {
    for (const deliveryKey of Object.keys(deliveries || {})) {
      removals[`internal/notificationDeliveryReceipts/${deliveryKey}`] = null;
    }
    removals[`internal/notificationDeliveryExpirations/${day}`] = null;
  }
  if (Object.keys(removals).length) await admin.database().ref().update(removals);
});

exports.cleanupCompletedMeetingRecords = onSchedule({
  schedule: "every 1 hours", timeZone: "America/Chicago", region: REGION,
}, async () => {
  await cleanupCompletedMeetingRecords(admin);
});

exports.cleanupCompletedClubOperations = onSchedule({
  schedule: "every 1 hours", timeZone: "America/Chicago", region: REGION,
}, async () => {
  await cleanupCompletedClubOperations(admin);
});

exports.retryNotificationDeliveries = onSchedule({
  schedule: "every 5 minutes", timeZone: "America/Chicago", region: REGION,
}, async () => retryNotificationDeliveries(admin));

exports.auditAuthIdentityLifecycle = onSchedule({
  schedule: "every day 02:47", timeZone: "America/Chicago", region: REGION,
}, async () => {
  let pageToken;
  do {
    const page = await admin.auth().listUsers(500, pageToken);
    for (const user of page.users) await auditAuthUser(admin, user);
    pageToken = page.pageToken;
  } while (pageToken);
});

exports.cleanupDeletedAccount = functionsV1.region(REGION).auth.user().onDelete(async (user) => {
  const db = admin.database();
  const [membershipsSnapshot, tokenHashSnapshot, devicesSnapshot] = await Promise.all([
    db.ref(`/userClubMemberships/${user.uid}`).get(),
    db.ref(`/calendarSubscriptions/${user.uid}/tokenHash`).get(),
    db.ref(`/notificationDevices/${user.uid}`).get(),
  ]);
  const memberships = membershipsSnapshot.val() || {};
  const updates = {
    [`userClubMemberships/${user.uid}`]: null,
    [`notificationDevices/${user.uid}`]: null,
    [`notificationReadState/${user.uid}`]: null,
    [`internal/notificationReadStatePruneCounters/${user.uid}`]: null,
    [`calendarSubscriptions/${user.uid}`]: null,
  };
  for (const [clubID, membership] of Object.entries(memberships)) {
    updates[`clubMemberships/${clubID}/${user.uid}`] = null;
    if (membership?.role === "pending") updates[`clubJoinRequests/${clubID}/${user.uid}`] = null;
    else Object.assign(updates, await userRSVPInvalidationUpdates(
      admin, user.uid, clubID, "identity-deleted"
    ));
    await appendLeaderAccessRevision(db, updates, clubID);
  }
  for (const [installationID, device] of Object.entries(devicesSnapshot.val() || {})) {
    updates[`internal/notificationInstallationOwners/${installationID}`] = null;
    if (device?.expiresDay) {
      const key = expirationKey(user.uid, installationID);
      updates[`internal/notificationDeviceExpirations/${device.expiresDay}/${key}`] = null;
    }
  }
  if (tokenHashSnapshot.val()) updates[`calendarTokens/${tokenHashSnapshot.val()}`] = null;
  await db.ref().update(updates);
});
