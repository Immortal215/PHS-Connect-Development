"use strict";

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const DEFAULT_ADMIN_EMAILS = new Set([
  "frank.mirandola@d214.org",
  "sharul.shah2008@gmail.com",
  "devin.t.ramirez@gmail.com",
]);

function adminEmails() {
  const configured = String(process.env.PHS_ADMIN_EMAILS || "")
    .split(",")
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean);
  return new Set([...DEFAULT_ADMIN_EMAILS, ...configured]);
}

function isAdmin(decodedToken) {
  return Boolean(decodedToken?.email && adminEmails().has(decodedToken.email.toLowerCase()));
}

function isAllowedIdentityEmail(value) {
  const email = String(value || "").trim().toLowerCase();
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

async function getRole(db, clubID, uid) {
  return (await getMembership(db, clubID, uid))?.role || null;
}

function identityMatchesMembership(membership, decodedToken) {
  const membershipEmail = String(membership?.email || "").trim().toLowerCase();
  const tokenEmail = String(decodedToken?.email || "").trim().toLowerCase();
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
  getRole,
  identityMatchesMembership,
  isAllowedIdentityEmail,
  isAdmin,
  isEligibleAuthUser,
  isEligibleDecodedIdentity,
  requireLeader,
  requireMembership,
  verifyRequest,
};
