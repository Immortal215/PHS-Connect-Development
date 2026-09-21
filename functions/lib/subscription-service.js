"use strict";

const crypto = require("crypto");
const { HttpError } = require("./access");
const { randomToken, sha256 } = require("./calendar-core");
const { REGION } = require("./constants");

const DEFAULT_PROJECT = "user-with-personal-tasks";
const projectID = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || DEFAULT_PROJECT;
const FEED_URL = process.env.CALENDAR_FEED_URL ||
  `https://${REGION}-${projectID}.cloudfunctions.net/calendarFeed`;

async function withSubscriptionLock(db, uid, operation) {
  const owner = crypto.randomUUID();
  const ref = db.ref(`/internal/calendarSubscriptionLocks/${uid}`);
  const now = Date.now();
  const result = await ref.transaction((current) => {
    if (current?.expiresAt > now) return;
    return { owner, expiresAt: now + 15000 };
  }, undefined, false);
  if (!result.committed || result.snapshot.val()?.owner !== owner) {
    throw new HttpError(409, "Subscription settings are already being updated. Try again.");
  }
  try {
    return await operation();
  } finally {
    await ref.transaction((current) => current?.owner === owner ? null : current, undefined, false);
  }
}

async function subscriptionStatus(admin, uid) {
  const state = (await admin.database().ref(`/calendarSubscriptions/${uid}`).get()).val() || {};
  return {
    active: Boolean(state.tokenHash && state.revoked !== true),
    generation: Number(state.generation || 0),
    createdAt: state.createdAt || null,
    updatedAt: state.updatedAt || null,
    revokedAt: state.revokedAt || null,
  };
}

async function rotateSubscription(admin, uid) {
  const db = admin.database();
  return withSubscriptionLock(db, uid, async () => {
    const state = (await db.ref(`/calendarSubscriptions/${uid}`).get()).val() || {};
    const generation = Number(state.generation || 0) + 1;
    const rawToken = randomToken();
    const tokenHash = sha256(rawToken);
    const timestamp = admin.serverTimestamp;
    const updates = {
      [`calendarSubscriptions/${uid}/tokenHash`]: tokenHash,
      [`calendarSubscriptions/${uid}/generation`]: generation,
      [`calendarSubscriptions/${uid}/revoked`]: false,
      [`calendarSubscriptions/${uid}/updatedAt`]: timestamp,
      [`calendarSubscriptions/${uid}/revokedAt`]: null,
      [`calendarSubscriptions/${uid}/cache`]: null,
      [`calendarTokens/${tokenHash}`]: { uid, generation, valid: true, createdAt: timestamp },
    };
    if (!state.createdAt) updates[`calendarSubscriptions/${uid}/createdAt`] = timestamp;
    if (state.tokenHash) {
      updates[`calendarTokens/${state.tokenHash}/valid`] = false;
      updates[`calendarTokens/${state.tokenHash}/revokedAt`] = timestamp;
    }
    await db.ref().update(updates);
    return { active: true, url: `${FEED_URL}?token=${encodeURIComponent(rawToken)}`, generation };
  });
}

async function revokeSubscription(admin, uid) {
  const db = admin.database();
  return withSubscriptionLock(db, uid, async () => {
    const state = (await db.ref(`/calendarSubscriptions/${uid}`).get()).val() || {};
    const generation = Number(state.generation || 0) + 1;
    const timestamp = admin.serverTimestamp;
    const updates = {
      [`calendarSubscriptions/${uid}/tokenHash`]: null,
      [`calendarSubscriptions/${uid}/generation`]: generation,
      [`calendarSubscriptions/${uid}/revoked`]: true,
      [`calendarSubscriptions/${uid}/updatedAt`]: timestamp,
      [`calendarSubscriptions/${uid}/revokedAt`]: timestamp,
      [`calendarSubscriptions/${uid}/cache`]: null,
    };
    if (state.tokenHash) {
      updates[`calendarTokens/${state.tokenHash}/valid`] = false;
      updates[`calendarTokens/${state.tokenHash}/revokedAt`] = timestamp;
    }
    await db.ref().update(updates);
    return { active: false, revoked: true, generation };
  });
}

module.exports = { FEED_URL, revokeSubscription, rotateSubscription, subscriptionStatus };
