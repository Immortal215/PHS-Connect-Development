"use strict";

const { addUtcDays, monthKeys, sha256 } = require("../../lib/calendar-core");
const { SCHOOL_TIME_ZONE } = require("../../lib/constants");

function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function parseLegacyParts(value) {
  const match = /^(\d{2})-(\d{2})-(\d{4}),\s*(\d{1,2}):(\d{2})\s*([AP]M)$/i
    .exec(String(value || "").trim());
  if (!match) return null;
  let hour = Number(match[4]);
  const minute = Number(match[5]);
  if (hour < 1 || hour > 12 || minute > 59) return null;
  hour %= 12;
  if (match[6].toUpperCase() === "PM") hour += 12;
  const parts = {
    year: Number(match[3]), month: Number(match[1]), day: Number(match[2]), hour, minute,
  };
  const probe = new Date(Date.UTC(parts.year, parts.month - 1, parts.day));
  if (probe.getUTCFullYear() !== parts.year || probe.getUTCMonth() !== parts.month - 1 ||
      probe.getUTCDate() !== parts.day) return null;
  return parts;
}

function renderedParts(epochMs) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: SCHOOL_TIME_ZONE, year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).formatToParts(new Date(epochMs));
  const map = Object.fromEntries(parts.map((part) => [part.type, Number(part.value)]));
  return { year: map.year, month: map.month, day: map.day, hour: map.hour, minute: map.minute };
}

function sameParts(first, second) {
  return ["year", "month", "day", "hour", "minute"]
    .every((key) => first[key] === second[key]);
}

function chicagoEpoch(parts) {
  const target = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute);
  let candidate = target;
  for (let index = 0; index < 3; index += 1) {
    const rendered = renderedParts(candidate);
    candidate += target - Date.UTC(
      rendered.year, rendered.month - 1, rendered.day, rendered.hour, rendered.minute
    );
  }
  if (!sameParts(renderedParts(candidate), parts)) return { error: "nonexistent-local-time" };
  const alternatives = [candidate - 3600000, candidate + 3600000]
    .filter((value) => sameParts(renderedParts(value), parts));
  if (alternatives.length) return { error: "ambiguous-local-time" };
  return { epoch: candidate / 1000 };
}

function strictLegacyDate(value) {
  const parts = parseLegacyParts(value);
  if (!parts) return { error: "invalid-format" };
  const resolved = chicagoEpoch(parts);
  return {
    ...resolved,
    date: `${parts.year}-${String(parts.month).padStart(2, "0")}-${String(parts.day).padStart(2, "0")}`,
  };
}

function strictLegacyDateOnly(value) {
  const match = /^(\d{2})-(\d{2})-(\d{4})(?:,.*)?$/.exec(String(value || "").trim());
  if (!match) return { error: "invalid-format" };
  const year = Number(match[3]);
  const month = Number(match[1]);
  const day = Number(match[2]);
  const probe = new Date(Date.UTC(year, month - 1, day));
  if (probe.getUTCFullYear() !== year || probe.getUTCMonth() !== month - 1 ||
      probe.getUTCDate() !== day) return { error: "invalid-date" };
  return {
    date: `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`,
    epoch: probe.getTime() / 1000,
  };
}

function legacyMeetingID(clubID, index, meeting) {
  return `m_${sha256(JSON.stringify([clubID, index, meeting])).slice(0, 28)}`;
}

function canonicalLegacyMeeting(
  clubID, index, legacy, emailToUID, report, updatedAt, suppliedMeetingID = null
) {
  const fullDay = legacy.fullDay === true;
  const start = fullDay ? strictLegacyDateOnly(legacy.startTime) : strictLegacyDate(legacy.startTime);
  const end = fullDay ? strictLegacyDateOnly(legacy.endTime) : strictLegacyDate(legacy.endTime);
  const meetingID = suppliedMeetingID || legacy.meetingID || legacyMeetingID(clubID, index, legacy);
  if (start.error || end.error) {
    report.malformedDates.push({
      clubID, index, meetingID, startTime: legacy.startTime || null,
      endTime: legacy.endTime || null, startError: start.error || null,
      endError: end.error || null,
    });
    return null;
  }
  const revisionTimestamp = Number(updatedAt) > 0 ? Number(updatedAt) : start.epoch;
  if (!(Number(updatedAt) > 0)) {
    report.missingRevisionTimestamps.push({
      clubID, index, meetingID, fallback: "meeting-start",
    });
  }
  const visibleEmails = Array.from(new Set(
    (legacy.visibleByArray || []).map(normalizeEmail).filter(Boolean)
  ));
  const visibilityUIDs = {};
  for (const email of visibleEmails) {
    const uid = emailToUID.get(email);
    if (uid) visibilityUIDs[uid] = true;
    else report.unresolvedVisibility.push({ clubID, index, meetingID, email });
  }
  const result = {
    meetingID,
    clubID,
    seriesID: legacy.seriesID || null,
    title: String(legacy.title || "").trim() || "Club Meeting",
    description: String(legacy.description || ""),
    location: String(legacy.location || ""),
    fullDay,
    timeZone: SCHOOL_TIME_ZONE,
    visibility: visibleEmails.length ? { mode: "uids", uids: visibilityUIDs } : { mode: "public" },
    recurrenceIntervalWeeks: legacy.recurrenceIntervalWeeks == null
      ? null : Number(legacy.recurrenceIntervalWeeks),
    recurrenceEndDate: legacy.recurrenceEndDate || null,
    createdAt: revisionTimestamp,
    updatedAt: revisionTimestamp,
    revision: 1,
    cancelled: false,
    cancelledAt: null,
  };
  if (fullDay) {
    result.startDate = start.date;
    result.endDateExclusive = addUtcDays(end.date, 1);
    if (result.endDateExclusive <= result.startDate) {
      result.endDateExclusive = addUtcDays(result.startDate, 1);
    }
  } else {
    if (end.epoch <= start.epoch) {
      report.malformedDates.push({
        clubID, index, meetingID, startTime: legacy.startTime,
        endTime: legacy.endTime, startError: null, endError: "end-not-after-start",
      });
      return null;
    }
    result.startUtc = start.epoch;
    result.endUtc = end.epoch;
    result.startDate = start.date;
    result.endDateExclusive = addUtcDays(end.date, 1);
  }
  return result;
}

function initialCalendarUpdates(clubID, meetings, timestamp, operationID) {
  const updates = {};
  const items = [];
  for (const meeting of meetings) {
    updates[`clubMeetings/${clubID}/${meeting.meetingID}`] = meeting;
    for (const month of monthKeys(meeting.startDate, meeting.endDateExclusive)) {
      updates[`clubCalendars/${clubID}/months/${month}/${meeting.meetingID}`] = meeting.revision;
    }
    items.push({
      meetingID: meeting.meetingID, operation: "upsert", meetingRevision: meeting.revision,
      startDate: meeting.startDate, endDateExclusive: meeting.endDateExclusive,
      updatedAt: meeting.updatedAt,
    });
  }
  updates[`clubCalendars/${clubID}/schemaVersion`] = 2;
  updates[`clubCalendars/${clubID}/sequence`] = items.length ? 1 : 0;
  updates[`clubCalendars/${clubID}/latestChange`] = items.length ? "0000000000000001" : "";
  updates[`clubCalendars/${clubID}/minimumChange`] = items.length ? "0000000000000001" : "";
  updates[`clubCalendars/${clubID}/updatedAt`] = timestamp;
  if (items.length) {
    updates[`clubCalendars/${clubID}/changes/0000000000000001`] = {
      operationID, committedAt: timestamp, items,
    };
  }
  updates[`clubs/${clubID}/calendarStorageVersion`] = 2;
  return updates;
}

module.exports = {
  canonicalLegacyMeeting,
  chicagoEpoch,
  initialCalendarUpdates,
  legacyMeetingID,
  parseLegacyParts,
  strictLegacyDate,
  strictLegacyDateOnly,
};
