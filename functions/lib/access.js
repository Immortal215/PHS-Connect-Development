"use strict";

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function normalizedEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function uniqueEmails(values) {
  return Array.from(new Set((values || []).map(normalizedEmail).filter(Boolean)));
}

function roleValue(value) {
  return typeof value === "string" ? value : value?.role;
}

function isAdmin(decodedToken) {
  return decodedToken?.phsSuperAdmin === true;
}

function isAllowedIdentityEmail(value) {
  const email = normalizedEmail(value);
  const parts = email.split("@");
  if (parts.length !== 2 || !parts[0] || !parts[1]) return false;
  const domain = parts[1];
  return domain === "gmail.com" || domain === "d214.org" || domain.endsWith(".d214.org");
}

function isEligibleAuthUser(user, fallbackEmail = null) {
  return user?.disabled !== true && user?.emailVerified === true &&
    isAllowedIdentityEmail(user.email || fallbackEmail);
}

function isEligibleDecodedIdentity(decodedToken) {
  return decodedToken?.email_verified === true && isAllowedIdentityEmail(decodedToken.email);
}

async function verifyRequest(admin, req) {
  const header = req.get("authorization") || "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) throw new HttpError(401, "Sign in is required.");
  try {
    // The second argument checks revocation/disabled state so a cached token
    // cannot keep using private API routes after an account is disabled.
    return await admin.auth().verifyIdToken(match[1], true);
  } catch {
    throw new HttpError(401, "Your sign-in session is no longer valid.");
  }
}

async function getMembership(db, clubID, uid) {
  return (await db.ref(`/clubMemberships/${clubID}/${uid}`).get()).val() || null;
}

function identityMatchesMembership(membership, decodedToken) {
  const membershipEmail = normalizedEmail(membership?.email);
  const tokenEmail = normalizedEmail(decodedToken?.email);
  return Boolean(membershipEmail && tokenEmail && decodedToken?.email_verified === true &&
    membershipEmail === tokenEmail);
}

async function requireMembership(db, clubID, decodedToken) {
  const membership = await getMembership(db, clubID, decodedToken.uid);
  if (!membership?.role || !identityMatchesMembership(membership, decodedToken)) {
    throw new HttpError(403, "You do not have access to this club.");
  }
  return membership.role;
}

async function requireLeader(db, clubID, decodedToken) {
  const membership = await getMembership(db, clubID, decodedToken.uid);
  if ((membership?.role !== "leader" || !identityMatchesMembership(membership, decodedToken)) &&
      !isAdmin(decodedToken)) {
    throw new HttpError(403, "Club leader access is required.");
  }
  return membership?.role || "leader";
}

module.exports = {
  HttpError,
  getMembership,
  identityMatchesMembership,
  isAllowedIdentityEmail,
  isAdmin,
  isEligibleAuthUser,
  isEligibleDecodedIdentity,
  normalizedEmail,
  requireLeader,
  requireMembership,
  roleValue,
  uniqueEmails,
  verifyRequest,
};
