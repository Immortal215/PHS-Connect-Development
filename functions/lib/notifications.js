"use strict";

const crypto = require("crypto");
const { HttpError, roleValue } = require("./access");
const { addUtcDays, canAccessMeeting } = require("./calendar-core");

const READ_STATE_LIMIT = 500;
const READ_STATE_PRUNE_INTERVAL = 25;
const currentProjectID = () => process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";

function safeInstallationID(value) {
  const id = String(value || "");
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(id)) throw new HttpError(400, "Invalid installation identifier.");
  return id;
}

function expirationKey(uid, installationID) {
  return crypto.createHash("sha256").update(`${uid}\u0000${installationID}`).digest("base64url");
}

function expirationDay(now = Date.now()) {
  return new Date(now + 60 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

function stateKey(scope) {
  return crypto.createHash("sha256").update(scope).digest("base64url").slice(0, 32);
}

function chatScope(chatID, threadName) { return `chat\u0000${chatID}\u0000${threadName || "general"}`; }
function meetingScope(meetingID) { return `meeting\u0000${meetingID}`; }

function compareReadRevision(type, first, second) {
  if (type === "meeting") return Number(first || 0) - Number(second || 0);
  const left = String(first || "");
  const right = String(second || "");
  return left === right ? 0 : left > right ? 1 : -1;
}

async function registerDevice(admin, decodedToken, body) {
  const db = admin.database();
  const installationID = safeInstallationID(body?.installationID);
  const token = String(body?.token || "");
  if (token.length < 32 || token.length > 4096) throw new HttpError(400, "Invalid notification token.");
  const projectID = String(body?.projectID || "");
  if (currentProjectID() && projectID !== currentProjectID()) throw new HttpError(400, "Firebase project mismatch.");
  const ownerRef = db.ref(`/internal/notificationInstallationOwners/${installationID}`);
  const owner = (await ownerRef.get()).val();
  const existingUIDs = Array.from(new Set([decodedToken.uid, owner].filter(Boolean)));
  const previousDevices = await Promise.all(existingUIDs.map(async (uid) => ({
    uid,
    value: (await db.ref(`/notificationDevices/${uid}/${installationID}`).get()).val(),
  })));
  const timestamp = admin.serverTimestamp;
  const expiresDay = expirationDay();
  const updates = {
    [`notificationDevices/${decodedToken.uid}/${installationID}`]: {
      token,
      platform: "ios",
      projectID,
      bundleID: String(body?.bundleID || ""),
      appVersion: String(body?.appVersion || ""),
      updatedAt: timestamp,
      expiresDay,
    },
    [`internal/notificationInstallationOwners/${installationID}`]: decodedToken.uid,
  };
  for (const previous of previousDevices) {
    if (previous.value?.expiresDay) {
      updates[`internal/notificationDeviceExpirations/${previous.value.expiresDay}/${expirationKey(previous.uid, installationID)}`] = null;
    }
  }
  updates[`internal/notificationDeviceExpirations/${expiresDay}/${expirationKey(decodedToken.uid, installationID)}`] = {
    uid: decodedToken.uid, installationID,
  };
  if (owner && owner !== decodedToken.uid) updates[`notificationDevices/${owner}/${installationID}`] = null;
  await db.ref().update(updates);
  return { registered: true };
}

async function unregisterDevice(admin, decodedToken, body) {
  const db = admin.database();
  const installationID = safeInstallationID(body?.installationID);
  const ownerRef = db.ref(`/internal/notificationInstallationOwners/${installationID}`);
  const owner = (await ownerRef.get()).val();
  const device = (await db.ref(`/notificationDevices/${decodedToken.uid}/${installationID}`).get()).val();
  const updates = { [`notificationDevices/${decodedToken.uid}/${installationID}`]: null };
  if (device?.expiresDay) {
    updates[`internal/notificationDeviceExpirations/${device.expiresDay}/${expirationKey(decodedToken.uid, installationID)}`] = null;
  }
  if (owner === decodedToken.uid) updates[`internal/notificationInstallationOwners/${installationID}`] = null;
  await db.ref().update(updates);
  return { registered: false };
}

async function registrationsForUID(db, uid) {
  const devices = (await db.ref(`/notificationDevices/${uid}`).get()).val() || {};
  return Object.entries(devices).flatMap(([installationID, value]) =>
    value?.token ? [{ uid, installationID, token: value.token, expiresDay: value.expiresDay }] : []
  );
}

async function readChatProfile(db, uid, chatID) {
  const [style, muted, registrations] = await Promise.all([
    db.ref(`/users/${uid}/chatNotifStyles/${chatID}`).get(),
    db.ref(`/users/${uid}/mutedThreadsByChat/${chatID}`).get(),
    registrationsForUID(db, uid),
  ]);
  return {
    registrations,
    style: style.val() || "all",
    muted: Array.isArray(muted.val()) ? muted.val() : [],
  };
}

function shouldNotifyChat(profile, threadName, isMention = false) {
  if (!profile.registrations.length || profile.style === "none") return false;
  if (profile.style === "mentions") return isMention;
  if (profile.style === "thread") return !profile.muted.includes(threadName);
  return true;
}

async function chatRecipients(db, { clubID, chatID, senderUID, threadName, isMention = false }) {
  const memberships = (await db.ref(`/clubMemberships/${clubID}`).get()).val() || {};
  const uids = Object.keys(memberships).filter((uid) => uid !== senderUID);
  const candidates = await Promise.all(uids.map(async (uid) => ({
    uid, profile: await readChatProfile(db, uid, chatID),
  })));
  return candidates.filter(({ profile }) => shouldNotifyChat(profile, threadName, isMention));
}

// Event time is stable across trigger retries; the hash distinguishes events in
// the same millisecond. Never use handler execution time for delayed events.
function reactionDescriptor(chatID, threadName, messageID, event) {
  const occurredAt = Date.parse(event.time);
  if (!Number.isFinite(occurredAt) || !event.id) throw new Error("Reaction event identity is missing.");
  return { type: "chat", scope: chatScope(chatID, threadName), chatID, threadName, messageID,
    revision: `reaction:${String(occurredAt).padStart(16, "0")}:${stateKey(event.id)}` };
}

function reactionTimestamp(revision) {
  const match = /^reaction:(\d{16}):[A-Za-z0-9_-]+$/.exec(String(revision));
  return match ? Number(match[1]) : null;
}

async function sendReactionNotification(admin, event) {
  const { chatID, messageID, emoji } = event.params;
  const before = Array.isArray(event.data.before.val()) ? event.data.before.val() : [];
  const after = Array.isArray(event.data.after.val()) ? event.data.after.val() : [];
  if (after.length <= before.length) return;
  const previous = new Set(before);
  const reactorUID = after.find((uid) => !previous.has(uid));
  if (!reactorUID) return;
  const db = admin.database();
  const [sender, thread, club] = await Promise.all([
    db.ref(`/chats/${chatID}/messages/${messageID}/sender`).get(),
    db.ref(`/chats/${chatID}/messages/${messageID}/threadName`).get(),
    db.ref(`/chats/${chatID}/clubID`).get(),
  ]);
  const receiverUID = sender.val();
  const clubID = club.val();
  const threadName = thread.val() || "general";
  if (!receiverUID || receiverUID === reactorUID || !clubID) return;
  const [receiverMembership, chatEnabled, clubName, reactorName, profile] = await Promise.all([
    db.ref(`/clubMemberships/${clubID}/${receiverUID}/role`).get(),
    db.ref(`/clubs/${clubID}/chatEnabled`).get(),
    db.ref(`/clubs/${clubID}/name`).get(),
    db.ref(`/users/${reactorUID}/userName`).get(),
    readChatProfile(db, receiverUID, chatID),
  ]);
  if (!receiverMembership.val() || chatEnabled.val() === false ||
      !shouldNotifyChat(profile, threadName, false)) return;
  const descriptor = reactionDescriptor(chatID, threadName, messageID, event);
  if (await alreadyRead(db, receiverUID, descriptor)) return;
  const reactor = reactorName.val() || "Someone";
  const clubTitle = clubName.val() || "Reaction";
  return sendToRegistrations(admin, profile.registrations, {
    notification: { title: `${reactor} • ${clubTitle}`, body: `reacted ${emoji}` },
    data: {
      type: "reaction", chatID, messageID, threadName, clubID,
      clubName: clubTitle, reactorUID, reactorName: reactor, emoji,
      logicalScope: stateKey(descriptor.scope), readRevision: descriptor.revision,
    },
    apns: { headers: { "apns-collapse-id": stateKey(descriptor.scope) }, payload: { aps: { threadId: `chat-${chatID}` } } },
  }, { deliveryID: `reaction-${event.id}`, descriptor });
}

async function meetingRecipientRegistrations(db, meeting) {
  const memberships = (await db.ref(`/clubMemberships/${meeting.clubID}`).get()).val() || {};
  const uids = Object.keys(memberships).filter((uid) => canAccessMeeting(
    meeting, roleValue(memberships[uid]), uid
  ));
  const registrations = await Promise.all(uids.map((uid) => registrationsForUID(db, uid)));
  return registrations.flat();
}

function formatMeetingTime(meeting) {
  if (meeting.fullDay) {
    return meeting.startDate === addUtcDays(meeting.endDateExclusive, -1)
      ? meeting.startDate : `${meeting.startDate} – ${addUtcDays(meeting.endDateExclusive, -1)}`;
  }
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: meeting.timeZone || "America/Chicago", dateStyle: "medium", timeStyle: "short",
  });
  return `${formatter.format(new Date(meeting.startUtc * 1000))} – ${formatter.format(new Date(meeting.endUtc * 1000))}`;
}

function isInvalidTokenError(code) {
  return code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token";
}

function registrationsByToken(registrations) {
  const result = new Map();
  for (const registration of registrations) {
    if (!result.has(registration.token)) result.set(registration.token, []);
    result.get(registration.token).push(registration);
  }
  return result;
}

function deliveryExpirationDay(now = Date.now()) {
  return new Date(now + 14 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

async function sendToRegistrations(
  admin, registrations, payload,
  { deliveryID = null, deliveryKey: suppliedDeliveryKey = null, descriptor = null, queueFailures = true } = {}
) {
  const byToken = registrationsByToken(registrations);
  const deliveryKey = suppliedDeliveryKey ||
    (deliveryID ? stateKey(`delivery\u0000${deliveryID}`) : null);
  const receiptsRef = deliveryKey
    ? admin.database().ref(`/internal/notificationDeliveryReceipts/${deliveryKey}`) : null;
  const receipts = receiptsRef ? (await receiptsRef.get()).val() || {} : {};
  const unique = Array.from(byToken.keys()).filter((token) => !receipts[stateKey(token)]);
  let successCount = 0;
  let failureCount = 0;
  for (let index = 0; index < unique.length; index += 500) {
    const tokens = unique.slice(index, index + 500);
    const result = await admin.messaging().sendEachForMulticast({ tokens, ...payload });
    successCount += result.successCount;
    failureCount += result.failureCount;
    const removals = {};
    result.responses.forEach((response, responseIndex) => {
      const token = tokens[responseIndex];
      const tokenKey = stateKey(token);
      const tokenRegistrations = byToken.get(token) || [];
      if (response.success && deliveryKey) {
        removals[`internal/notificationDeliveryReceipts/${deliveryKey}/${tokenKey}`] = Date.now();
        removals[`internal/notificationRetryJobs/${stateKey(`${deliveryKey}\u0000${tokenKey}`)}`] = null;
      } else if (!response.success && isInvalidTokenError(response.error?.code)) {
        for (const item of tokenRegistrations) {
          removals[`notificationDevices/${item.uid}/${item.installationID}`] = null;
          removals[`internal/notificationInstallationOwners/${item.installationID}`] = null;
          if (item.expiresDay) {
            removals[`internal/notificationDeviceExpirations/${item.expiresDay}/${expirationKey(item.uid, item.installationID)}`] = null;
          }
        }
      } else if (!response.success && queueFailures && deliveryKey) {
        removals[`internal/notificationRetryJobs/${stateKey(`${deliveryKey}\u0000${tokenKey}`)}`] = {
          deliveryKey, tokenKey, token, registrations: tokenRegistrations,
          payload, descriptor, attempts: 0, nextAttempt: Date.now() + 60000,
          createdAt: Date.now(),
        };
      }
    });
    if (deliveryKey) {
      removals[`internal/notificationDeliveryExpirations/${deliveryExpirationDay()}/${deliveryKey}`] = true;
    }
    if (Object.keys(removals).length) await admin.database().ref().update(removals);
  }
  return { successCount, failureCount };
}

async function retryNotificationDeliveries(admin, limit = 200) {
  const db = admin.database();
  const snapshot = await db.ref("/internal/notificationRetryJobs")
    .orderByChild("nextAttempt").endAt(Date.now()).limitToFirst(limit).get();
  for (const [jobID, original] of Object.entries(snapshot.val() || {})) {
    const ref = db.ref(`/internal/notificationRetryJobs/${jobID}`);
    const owner = crypto.randomUUID();
    const lease = await ref.transaction((current) => {
      if (!current || current.nextAttempt > Date.now()) return;
      if (current.leaseExpiresAt > Date.now()) return;
      return { ...current, owner, leaseExpiresAt: Date.now() + 60000 };
    }, undefined, false);
    if (!lease.committed || lease.snapshot.val()?.owner !== owner) continue;
    const job = lease.snapshot.val();
    try {
      const active = [];
      for (const registration of job.registrations || []) {
        const current = (await db.ref(
          `/notificationDevices/${registration.uid}/${registration.installationID}/token`
        ).get()).val();
        if (current !== job.token) continue;
        if (job.descriptor && await alreadyRead(db, registration.uid, job.descriptor)) continue;
        active.push(registration);
      }
      if (!active.length) {
        await ref.remove();
        continue;
      }
      const result = await sendToRegistrations(admin, active, job.payload, {
        deliveryKey: job.deliveryKey,
        descriptor: job.descriptor,
        queueFailures: false,
      });
      if (result.failureCount === 0) await ref.remove();
      else {
        const attempts = Number(job.attempts || 0) + 1;
        if (attempts >= 8) await ref.remove();
        else await ref.update({
          attempts,
          nextAttempt: Date.now() + Math.min(6 * 60 * 60 * 1000, 60000 * (2 ** attempts)),
          owner: null,
          leaseExpiresAt: null,
        });
      }
    } catch (error) {
      await ref.update({ nextAttempt: Date.now() + 5 * 60 * 1000, owner: null, leaseExpiresAt: null });
      console.error("Notification retry failed", { jobID, error });
    }
  }
}

function readDescriptor(body) {
  const type = String(body?.type || "");
  if (type === "chat") {
    const chatID = String(body.chatID || "");
    const threadName = String(body.threadName || "general");
    const revision = String(body.messageID || "");
    if (!chatID || !revision) throw new HttpError(400, "Chat read state is incomplete.");
    return { type, scope: chatScope(chatID, threadName), revision, chatID, threadName, messageID: revision };
  }
  if (type === "meeting") {
    const meetingID = String(body.meetingID || "");
    const revision = Number(body.revision || 0);
    if (!meetingID || !Number.isInteger(revision) || revision < 1) throw new HttpError(400, "Meeting read state is incomplete.");
    return { type, scope: meetingScope(meetingID), revision, meetingID };
  }
  throw new HttpError(400, "Unknown notification read-state type.");
}

async function readState(db, uid, descriptor) {
  return (await db.ref(`/notificationReadState/${uid}/${stateKey(descriptor.scope)}`).get()).val();
}

async function alreadyRead(db, uid, descriptor) {
  const state = await readState(db, uid, descriptor);
  const reactionAt = reactionTimestamp(descriptor.revision);
  if (reactionAt !== null) return Boolean(state && Number(state.seenAt || 0) >= reactionAt);
  return Boolean(state && compareReadRevision(descriptor.type, state.revision, descriptor.revision) >= 0);
}

async function pruneReadState(db, uid) {
  const ref = db.ref(`/notificationReadState/${uid}`);
  const target = READ_STATE_LIMIT - READ_STATE_PRUNE_INTERVAL;
  // A legacy account may already exceed one query page; keep each read bounded.
  while (true) {
    const snapshot = await ref.orderByChild("seenAt").limitToFirst(READ_STATE_LIMIT + READ_STATE_PRUNE_INTERVAL).get();
    if (snapshot.numChildren() <= target) return;
    const removals = {};
    let remaining = snapshot.numChildren() - target;
    snapshot.forEach((child) => {
      if (remaining > 0) { removals[child.key] = null; remaining -= 1; }
    });
    await ref.update(removals);
  }
}

async function recordNewReadScope(db, uid) {
  const ref = db.ref(`/internal/notificationReadStatePruneCounters/${uid}`);
  const owner = crypto.randomUUID();
  const now = Date.now();
  const claim = await ref.transaction((current) => {
    if (!current || (current.owner && Number(current.leaseExpiresAt || 0) <= now)) {
      return { created: 0, owner, leaseExpiresAt: now + 60000 };
    }
    const created = Number(current.created || 0) + 1;
    return created >= READ_STATE_PRUNE_INTERVAL && !current.owner
      ? { created: 0, owner, leaseExpiresAt: now + 60000 }
      : { ...current, created };
  }, undefined, false);
  if (!claim.committed || claim.snapshot.val()?.owner !== owner) return;
  while (true) {
    await pruneReadState(db, uid);
    const completion = await ref.transaction((current) => {
      if (current?.owner !== owner) return;
      return Number(current.created || 0) > 0
        ? { created: 0, owner, leaseExpiresAt: Date.now() + 60000 }
        : { created: 0, owner: null, leaseExpiresAt: null };
    }, undefined, false);
    if (!completion.committed || completion.snapshot.val()?.owner !== owner) return;
  }
}

async function acknowledgeNotification(admin, decodedToken, body) {
  const db = admin.database();
  const descriptor = readDescriptor(body);
  const key = stateKey(descriptor.scope);
  const ref = db.ref(`/notificationReadState/${decodedToken.uid}/${key}`);
  const seenAt = Date.now();
  let createdNewScope = false;
  const result = await ref.transaction((current) => {
    createdNewScope = current == null;
    if (current && compareReadRevision(descriptor.type, current.revision, descriptor.revision) >= 0) {
      // Reopening a thread can observe new reactions without a new message.
      // Preserve the message cursor while advancing the reaction read watermark.
      if (descriptor.type === "chat" && seenAt > Number(current.seenAt || 0)) {
        return { ...current, seenAt };
      }
      return;
    }
    const value = { ...descriptor, scope: null, seenAt: Math.max(seenAt, Number(current?.seenAt || 0)) };
    delete value.scope;
    return value;
  }, undefined, false);
  const saved = result.snapshot.val();
  const sourceInstallationID = String(body?.installationID || "");
  if (result.committed) {
    const registrations = (await registrationsForUID(db, decodedToken.uid))
      .filter((item) => item.installationID !== sourceInstallationID);
    if (registrations.length) await sendToRegistrations(admin, registrations, {
      data: {
        type: "notificationReadSync",
        uid: decodedToken.uid,
        readStateKey: key,
        readType: descriptor.type,
        revision: String(saved.revision),
        seenAt: String(saved.seenAt || 0),
        chatID: saved.chatID || "",
        threadName: saved.threadName || "",
        messageID: saved.messageID || "",
        meetingID: saved.meetingID || "",
      },
      apns: { headers: { "apns-priority": "5", "apns-push-type": "background" }, payload: { aps: { contentAvailable: true } } },
    });
  }
  if (result.committed && createdNewScope) {
    await recordNewReadScope(db, decodedToken.uid);
  }
  return { acknowledged: true, key, state: saved };
}

async function notificationReadStates(admin, decodedToken) {
  const values = (await admin.database().ref(`/notificationReadState/${decodedToken.uid}`).get()).val() || {};
  return { states: values };
}

module.exports = {
  acknowledgeNotification, alreadyRead, chatRecipients, chatScope, compareReadRevision,
  expirationDay, expirationKey,
  formatMeetingTime, meetingRecipientRegistrations, meetingScope, notificationReadStates, readChatProfile,
  readDescriptor, registerDevice, registrationsByToken, registrationsForUID, sendToRegistrations,
  reactionDescriptor, reactionTimestamp, sendReactionNotification,
  retryNotificationDeliveries, shouldNotifyChat, stateKey, unregisterDevice,
};
