"use strict";

const SCHOOL_TIME_ZONE = "America/Chicago";
const FEED_LOOKBACK_DAYS = 30;
const FEED_LOOKAHEAD_DAYS = 365;
const CANCELLED_RETENTION_DAYS = 400;
const FEED_LOCK_SECONDS = 30;
const REGION = "us-central1";
const MEETING_WEB_BASE = process.env.MEETING_WEB_BASE ||
  "https://user-with-personal-tasks.web.app/meeting";

module.exports = {
  CANCELLED_RETENTION_DAYS,
  FEED_LOCK_SECONDS,
  FEED_LOOKAHEAD_DAYS,
  FEED_LOOKBACK_DAYS,
  MEETING_WEB_BASE,
  REGION,
  SCHOOL_TIME_ZONE,
};
