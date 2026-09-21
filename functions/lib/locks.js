"use strict";

const crypto = require("crypto");
const { HttpError } = require("./access");

async function releaseLocks(lock) {
  await Promise.all(lock.acquired.map(({ ref }) => ref.transaction(
    (current) => current?.owner === lock.owner ? null : current, undefined, false
  )));
}

async function acquireLocks(db, path, ids, ttlMs = 30000) {
  const owner = crypto.randomUUID();
  const acquired = [];
  for (const id of Array.from(new Set(ids)).sort()) {
    const ref = db.ref(`/internal/${path}/${id}`);
    const now = Date.now();
    const result = await ref.transaction((current) => {
      if (current?.expiresAt > now) return;
      return { owner, expiresAt: now + ttlMs };
    }, undefined, false);
    if (!result.committed || result.snapshot.val()?.owner !== owner) {
      await releaseLocks({ owner, acquired });
      throw new HttpError(409, "This information changed elsewhere. Refresh and try again.");
    }
    acquired.push({ ref });
  }
  return { owner, acquired };
}

module.exports = { acquireLocks, releaseLocks };
