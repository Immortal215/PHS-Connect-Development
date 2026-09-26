"use strict";

const { randomUUID } = require("node:crypto");
const {
  HttpError, isAdmin, isAllowedIdentityEmail, normalizedEmail,
} = require("./access");

function adminEntry(user) {
  return {
    uid: user.uid,
    email: user.email || null,
    disabled: user.disabled === true,
    emailVerified: user.emailVerified === true,
  };
}

async function requireCurrentAdmin(auth, decoded) {
  if (!isAdmin(decoded)) throw new HttpError(403, "Administrator access is required.");
  let user;
  try {
    user = await auth.getUser(decoded.uid);
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      throw new HttpError(403, "Administrator access is required.");
    }
    throw error;
  }
  if (user.disabled || !user.emailVerified || user.customClaims?.phsSuperAdmin !== true) {
    throw new HttpError(403, "Administrator access is required.");
  }
  return user;
}

async function adminUsers(auth) {
  const users = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    users.push(...page.users.filter((user) => user.customClaims?.phsSuperAdmin === true));
    pageToken = page.pageToken;
  } while (pageToken);
  return users;
}

async function listAdmins(admin, decoded) {
  const auth = admin.auth();
  await requireCurrentAdmin(auth, decoded);
  const users = await adminUsers(auth);
  return users.map(adminEntry).sort((a, b) =>
    (a.email || a.uid).localeCompare(b.email || b.uid));
}

async function withClaimMutationLock(admin, action) {
  const ref = admin.database().ref("/internal/superAdminClaimMutationLock");
  const owner = randomUUID();
  const now = Date.now();
  const claim = await ref.transaction((current) => {
    if (current?.expiresAt > now) return;
    return { owner, expiresAt: now + 120000 };
  }, undefined, false);
  if (!claim.committed || claim.snapshot.val()?.owner !== owner) {
    throw new HttpError(409, "Another administrator change is in progress. Try again.");
  }
  try {
    return await action();
  } finally {
    try {
      await ref.transaction((current) => current?.owner === owner ? null : undefined,
        undefined, false);
    } catch (error) {
      console.error("Could not release administrator change lock", { error });
    }
  }
}

function validEmail(value) {
  const email = normalizedEmail(value);
  if (email.length > 320 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
      !isAllowedIdentityEmail(email)) {
    throw new HttpError(400, "Enter a valid PHS Connect account email.");
  }
  return email;
}

async function grantAdmin(admin, decoded, body) {
  const email = validEmail(body?.email);
  return withClaimMutationLock(admin, async () => {
    const auth = admin.auth();
    await requireCurrentAdmin(auth, decoded);
    let target;
    try {
      target = await auth.getUserByEmail(email);
    } catch (error) {
      if (error.code === "auth/user-not-found") {
        throw new HttpError(404, "That person must create an account before becoming an administrator.");
      }
      throw error;
    }
    if (normalizedEmail(target.email) !== email || target.disabled || !target.emailVerified) {
      throw new HttpError(409, "That account must be enabled and have a verified email.");
    }
    if (target.customClaims?.phsSuperAdmin !== true) {
      await auth.setCustomUserClaims(target.uid, {
        ...target.customClaims, phsSuperAdmin: true,
      });
      target = await auth.getUser(target.uid);
      if (target.customClaims?.phsSuperAdmin !== true) {
        throw new Error("Administrator claim verification failed.");
      }
      console.info("Administrator granted", { actorUID: decoded.uid, targetUID: target.uid });
    }
    return adminEntry(target);
  });
}

async function revokeAdmin(admin, decoded, body) {
  const uid = typeof body?.uid === "string" ? body.uid.trim() : "";
  if (!uid || uid.length > 128) throw new HttpError(400, "Choose an administrator to remove.");
  return withClaimMutationLock(admin, async () => {
    const auth = admin.auth();
    await requireCurrentAdmin(auth, decoded);
    let target;
    try {
      target = await auth.getUser(uid);
    } catch (error) {
      if (error.code === "auth/user-not-found") throw new HttpError(404, "Account not found.");
      throw error;
    }
    if (target.customClaims?.phsSuperAdmin !== true) return { removedUID: uid };
    const users = await adminUsers(auth);
    const active = users.filter((user) => !user.disabled && user.emailVerified);
    if (!target.disabled && target.emailVerified && active.length <= 1) {
      throw new HttpError(409, "At least one active administrator must remain.");
    }
    const claims = { ...target.customClaims };
    delete claims.phsSuperAdmin;
    await auth.setCustomUserClaims(uid, claims);
    const updated = await auth.getUser(uid);
    if (updated.customClaims?.phsSuperAdmin === true) {
      throw new Error("Administrator removal verification failed.");
    }
    console.info("Administrator removed", { actorUID: decoded.uid, targetUID: uid });
    return { removedUID: uid };
  });
}

module.exports = { grantAdmin, listAdmins, revokeAdmin };
