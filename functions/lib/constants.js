"use strict";

const SCHOOL_TIME_ZONE = "America/Chicago";
const FEED_LOOKBACK_DAYS = 30;
const FEED_LOCK_SECONDS = 30;
const REGION = "us-central1";

function runtimeProjectID(env = process.env) {
  let firebaseProject = "";
  if (env.FIREBASE_CONFIG) {
    let config;
    try {
      config = JSON.parse(env.FIREBASE_CONFIG);
    } catch {
      throw new Error("FIREBASE_CONFIG must contain valid JSON.");
    }
    firebaseProject = config.projectId || "";
  }
  const projectIDs = [env.GCLOUD_PROJECT, env.GCP_PROJECT, firebaseProject].filter(Boolean);
  if (!projectIDs.length) throw new Error("Firebase project ID is required for generated URLs.");
  if (projectIDs.some((id) => id !== projectIDs[0])) {
    throw new Error("Conflicting Firebase project IDs in runtime configuration.");
  }
  if (!/^[a-z][a-z0-9-]{4,29}$/.test(projectIDs[0])) {
    throw new Error("Invalid Firebase project ID in runtime configuration.");
  }
  return projectIDs[0];
}

function configuredURL(value, env, label) {
  let url;
  try { url = new URL(value); }
  catch { throw new Error(`${label} must be an absolute URL.`); }
  const localOverride = (env.FUNCTIONS_EMULATOR === "true" || env.NODE_ENV === "test")
    && ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname);
  if ((url.protocol !== "https:" && !(localOverride && url.protocol === "http:"))
    || url.username || url.password || url.search || url.hash) {
    throw new Error(`${label} must be a safe HTTPS URL or local emulator URL.`);
  }
  const hasProjectMetadata = Boolean(env.GCLOUD_PROJECT || env.GCP_PROJECT || env.FIREBASE_CONFIG);
  if (!hasProjectMetadata && env.FUNCTIONS_EMULATOR !== "true" && env.NODE_ENV !== "test") {
    throw new Error("Firebase project ID is required for generated URLs.");
  }
  if (hasProjectMetadata) {
    const projectID = runtimeProjectID(env);
    const hostingHost = url.hostname.endsWith(".web.app")
      || url.hostname.endsWith(".firebaseapp.com");
    if (hostingHost && url.hostname !== `${projectID}.web.app`
      && url.hostname !== `${projectID}.firebaseapp.com`) {
      throw new Error(`${label} points to a different Firebase project.`);
    }
    if (url.hostname.endsWith(".cloudfunctions.net")
      && url.hostname !== `${REGION}-${projectID}.cloudfunctions.net`) {
      throw new Error(`${label} points to a different Firebase project.`);
    }
  }
  return url.toString().replace(/\/$/, "");
}

function meetingWebBase(env = process.env) {
  if (env.MEETING_WEB_BASE) {
    return configuredURL(env.MEETING_WEB_BASE, env, "MEETING_WEB_BASE");
  }
  return `https://${runtimeProjectID(env)}.web.app/meeting`;
}

module.exports = {
  FEED_LOCK_SECONDS,
  FEED_LOOKBACK_DAYS,
  configuredURL,
  meetingWebBase,
  REGION,
  runtimeProjectID,
  SCHOOL_TIME_ZONE,
};
