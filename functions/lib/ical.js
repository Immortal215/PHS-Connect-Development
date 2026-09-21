"use strict";

const { MEETING_WEB_BASE, SCHOOL_TIME_ZONE } = require("./constants");

function escapeText(value) {
  return String(value || "")
    .replace(/\\/g, "\\\\")
    .replace(/\r\n|\r|\n/g, "\\n")
    .replace(/,/g, "\\,")
    .replace(/;/g, "\\;");
}

function foldLine(line) {
  const chunks = [];
  let current = "";
  let limit = 75;

  for (const character of String(line)) {
    const candidate = current + character;
    if (Buffer.byteLength(candidate, "utf8") > limit && current) {
      chunks.push(current);
      current = character;
      limit = 74;
    } else {
      current = candidate;
    }
  }
  chunks.push(current);
  return chunks.join("\r\n ");
}

function utcStamp(epochSeconds) {
  return new Date(epochSeconds * 1000)
    .toISOString()
    .replace(/[-:]/g, "")
    .replace(/\.\d{3}Z$/, "Z");
}

function localStamp(epochSeconds, timeZone = SCHOOL_TIME_ZONE) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date(epochSeconds * 1000));
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}${values.month}${values.day}T${values.hour}${values.minute}${values.second}`;
}

function dateStamp(dateOnly) {
  return String(dateOnly).replace(/-/g, "");
}

function meetingLines(meeting, clubName) {
  const updatedAt = Number(meeting.updatedAt || meeting.createdAt || 0);
  const stableRevisionTime = updatedAt > 0 ? updatedAt : meeting.fullDay === true
    ? Date.parse(`${meeting.startDate}T00:00:00Z`) / 1000
    : Number(meeting.startUtc || 0);
  const lines = [
    "BEGIN:VEVENT",
    `UID:${escapeText(meeting.meetingID)}@phs-connect`,
    `SEQUENCE:${Math.max(0, Number(meeting.revision || 0))}`,
    `DTSTAMP:${utcStamp(stableRevisionTime)}`,
    `LAST-MODIFIED:${utcStamp(stableRevisionTime)}`,
  ];

  if (meeting.fullDay === true) {
    lines.push(`DTSTART;VALUE=DATE:${dateStamp(meeting.startDate)}`);
    lines.push(`DTEND;VALUE=DATE:${dateStamp(meeting.endDateExclusive)}`);
  } else {
    const timeZone = meeting.timeZone || SCHOOL_TIME_ZONE;
    lines.push(`DTSTART;TZID=${timeZone}:${localStamp(meeting.startUtc, timeZone)}`);
    lines.push(`DTEND;TZID=${timeZone}:${localStamp(meeting.endUtc, timeZone)}`);
  }

  lines.push(`SUMMARY:${escapeText(meeting.title || "Club Meeting")}`);
  if (meeting.description) lines.push(`DESCRIPTION:${escapeText(meeting.description)}`);
  if (meeting.location) lines.push(`LOCATION:${escapeText(meeting.location)}`);
  if (clubName) lines.push(`CATEGORIES:${escapeText(clubName)}`);
  lines.push(`URL:${MEETING_WEB_BASE}/${encodeURIComponent(meeting.clubID)}/${encodeURIComponent(meeting.meetingID)}`);
  if (meeting.cancelled === true) {
    lines.push("STATUS:CANCELLED");
    lines.push("TRANSP:TRANSPARENT");
  } else {
    lines.push("STATUS:CONFIRMED");
  }
  lines.push("END:VEVENT");
  return lines;
}

function generateCalendar({ meetings, clubNames, calendarName = "PHS Connect" }) {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//PHS Connect//Private Club Calendar//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    `X-WR-CALNAME:${escapeText(calendarName)}`,
    `X-WR-TIMEZONE:${SCHOOL_TIME_ZONE}`,
    "BEGIN:VTIMEZONE",
    `TZID:${SCHOOL_TIME_ZONE}`,
    `X-LIC-LOCATION:${SCHOOL_TIME_ZONE}`,
    "BEGIN:DAYLIGHT",
    "TZOFFSETFROM:-0600",
    "TZOFFSETTO:-0500",
    "TZNAME:CDT",
    "DTSTART:20070311T020000",
    "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU",
    "END:DAYLIGHT",
    "BEGIN:STANDARD",
    "TZOFFSETFROM:-0500",
    "TZOFFSETTO:-0600",
    "TZNAME:CST",
    "DTSTART:20071104T020000",
    "RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU",
    "END:STANDARD",
    "END:VTIMEZONE",
  ];
  for (const meeting of meetings) {
    lines.push(...meetingLines(meeting, clubNames[meeting.clubID] || ""));
  }
  lines.push("END:VCALENDAR");
  return `${lines.map(foldLine).join("\r\n")}\r\n`;
}

module.exports = {
  escapeText,
  foldLine,
  generateCalendar,
  localStamp,
  meetingLines,
};
