"use strict";

const crypto = require("crypto");
const {
  FEED_LOOKBACK_DAYS,
  SCHOOL_TIME_ZONE,
} = require("./constants");

function sha256(value) {
  return crypto.createHash("sha256").update(String(value)).digest("hex");
}

function randomToken() {
  return crypto.randomBytes(32).toString("base64url");
}

function dateOnlyInTimeZone(date, timeZone = SCHOOL_TIME_ZONE) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function addUtcDays(dateOnly, days) {
  const [year, month, day] = dateOnly.split("-").map(Number);
  const result = new Date(Date.UTC(year, month - 1, day + days));
  return result.toISOString().slice(0, 10);
}

function addCalendarYears(dateOnly, years) {
  const [year, month, day] = dateOnly.split("-").map(Number);
  const candidate = new Date(Date.UTC(year + years, month - 1, day));
  if (candidate.getUTCMonth() !== month - 1) candidate.setUTCDate(0);
  return candidate.toISOString().slice(0, 10);
}

function fixedFeedWindow(now = new Date()) {
  const today = dateOnlyInTimeZone(now);
  return {
    dayKey: today,
    startDate: addUtcDays(today, -FEED_LOOKBACK_DAYS),
    endDateExclusive: addUtcDays(addCalendarYears(today, 1), 1),
  };
}

function monthKeys(startDate, endDateExclusive) {
  const [startYear, startMonth] = startDate.split("-").map(Number);
  const inclusiveEnd = addUtcDays(endDateExclusive, -1);
  const [endYear, endMonth] = inclusiveEnd.split("-").map(Number);
  const keys = [];
  let year = startYear;
  let month = startMonth;
  while (year < endYear || (year === endYear && month <= endMonth)) {
    keys.push(`${year}-${String(month).padStart(2, "0")}`);
    month += 1;
    if (month === 13) {
      month = 1;
      year += 1;
    }
  }
  return keys;
}

function zonedMidnightEpoch(dateOnly, timeZone = SCHOOL_TIME_ZONE) {
  const [year, month, day] = dateOnly.split("-").map(Number);
  const target = Date.UTC(year, month - 1, day);
  let candidate = target;
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hourCycle: "h23",
    }).formatToParts(new Date(candidate));
    const value = Object.fromEntries(parts.map((part) => [part.type, part.value]));
    const represented = Date.UTC(
      Number(value.year),
      Number(value.month) - 1,
      Number(value.day),
      Number(value.hour),
      Number(value.minute),
      Number(value.second)
    );
    candidate += target - represented;
  }
  return candidate / 1000;
}

function overlapsWindow(meeting, window) {
  if (meeting.fullDay === true) {
    return meeting.startDate < window.endDateExclusive &&
      meeting.endDateExclusive > window.startDate;
  }
  const startBoundary = zonedMidnightEpoch(window.startDate);
  const endBoundary = zonedMidnightEpoch(window.endDateExclusive);
  return Number(meeting.startUtc) < endBoundary && Number(meeting.endUtc) > startBoundary;
}

function canAccessMeeting(meeting, role, uid) {
  if (!role) return false;
  const visibility = meeting.visibility || { mode: "public" };
  if (role === "leader") return true;
  if (visibility.mode === "leaders") return false;
  if (visibility.mode === "uids") {
    return visibility.uids?.[uid] === true;
  }
  return true;
}

function dependencyFingerprint({ memberships, clubCursors, clubMetadata, dayKey }) {
  const clubs = Object.keys(memberships || {}).sort().map((clubID) => ({
    clubID,
    role: memberships[clubID]?.role || memberships[clubID],
    cursor: clubCursors[clubID] || "",
    name: clubMetadata[clubID]?.name || "",
  }));
  return sha256(JSON.stringify({ clubs, dayKey }));
}

function rsvpCutoffEpoch(meeting) {
  if (meeting.fullDay === true) return zonedMidnightEpoch(meeting.startDate);
  return Number(meeting.startUtc);
}

function validateMeeting(meeting) {
  if (!meeting || typeof meeting !== "object") throw new Error("Meeting is required.");
  if (!meeting.clubID || !meeting.title?.trim()) throw new Error("Meeting club and title are required.");
  if (meeting.fullDay === true) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(meeting.startDate || "") ||
        !/^\d{4}-\d{2}-\d{2}$/.test(meeting.endDateExclusive || "") ||
        meeting.endDateExclusive <= meeting.startDate) {
      throw new Error("All-day meetings require valid date-only start and exclusive end dates.");
    }
  } else if (!Number.isFinite(Number(meeting.startUtc)) ||
      !Number.isFinite(Number(meeting.endUtc)) ||
      Number(meeting.endUtc) <= Number(meeting.startUtc)) {
    throw new Error("Timed meetings require valid UTC start and end values.");
  }
}

module.exports = {
  addUtcDays,
  addCalendarYears,
  canAccessMeeting,
  dateOnlyInTimeZone,
  dependencyFingerprint,
  fixedFeedWindow,
  monthKeys,
  overlapsWindow,
  randomToken,
  rsvpCutoffEpoch,
  sha256,
  validateMeeting,
  zonedMidnightEpoch,
};
