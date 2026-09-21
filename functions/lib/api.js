"use strict";

const { HttpError, verifyRequest } = require("./access");
const { getCalendarResponse } = require("./calendar-service");
const { addUtcDays, dateOnlyInTimeZone } = require("./calendar-core");
const { accessSnapshot, membershipAction, reconcileIdentity, saveClub } = require("./membership-service");
const {
  deleteMeetings,
  getRSVP,
  listMeetings,
  listRSVPs,
  nextPublicMeeting,
  saveMeetings,
  setRSVP,
  syncClubCalendar,
} = require("./meeting-service");
const {
  revokeSubscription, rotateSubscription, subscriptionStatus,
} = require("./subscription-service");
const {
  acknowledgeNotification, notificationReadStates, registerDevice, unregisterDevice,
} = require("./notifications");

function sendJSON(res, status, value) {
  res.status(status).set("Cache-Control", "private, no-store").json(value);
}

function validatedDate(value, name) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value || "")) throw new HttpError(400, `${name} must be a date.`);
  return value;
}

function route(req) {
  return String(req.path || "/").replace(/\/+$/, "") || "/";
}

function apiHandler(admin) {
  return async (req, res) => {
    try {
      const decoded = await verifyRequest(admin, req);
      const path = route(req);
      if (req.method === "GET" && path === "/meetings") {
        const today = dateOnlyInTimeZone(new Date());
        const startDate = validatedDate(req.query.start || addUtcDays(today, -30), "start");
        const endDateExclusive = validatedDate(req.query.end || addUtcDays(today, 366), "end");
        if (endDateExclusive <= startDate) throw new HttpError(400, "The meeting range is invalid.");
        return sendJSON(res, 200, { meetings: await listMeetings(admin, decoded, startDate, endDateExclusive) });
      }
      if (req.method === "POST" && path === "/meetings/save") {
        return sendJSON(res, 200, await saveMeetings(admin, decoded, req.body));
      }
      if (req.method === "POST" && path === "/meetings/delete") {
        return sendJSON(res, 200, await deleteMeetings(admin, decoded, req.body));
      }
      if (req.method === "GET" && path === "/calendar/sync") {
        const start = validatedDate(String(req.query.start || ""), "start");
        const end = validatedDate(String(req.query.end || ""), "end");
        if (end <= start) throw new HttpError(400, "The meeting range is invalid.");
        return sendJSON(res, 200, await syncClubCalendar(admin, decoded, { ...req.query, start, end }));
      }
      if (req.method === "GET" && path === "/clubs/next-meeting") {
        return sendJSON(res, 200, { meeting: await nextPublicMeeting(admin, String(req.query.clubID || "")) });
      }
      if (req.method === "GET" && path === "/clubs/access") {
        return sendJSON(res, 200, await accessSnapshot(admin, decoded, String(req.query.clubID || "")));
      }
      if (req.method === "POST" && path === "/membership") {
        return sendJSON(res, 200, await membershipAction(admin, decoded, req.body));
      }
      if (req.method === "POST" && path === "/clubs/save") {
        return sendJSON(res, 200, await saveClub(admin, decoded, req.body));
      }
      if (req.method === "POST" && path === "/identity/reconcile") {
        return sendJSON(res, 200, await reconcileIdentity(admin, decoded));
      }
      if (req.method === "GET" && path === "/rsvp") {
        return sendJSON(res, 200, { status: await getRSVP(
          admin, decoded, String(req.query.clubID || ""), String(req.query.meetingID || "")
        ) });
      }
      if (req.method === "PUT" && path === "/rsvp") {
        return sendJSON(res, 200, await setRSVP(admin, decoded, req.body));
      }
      if (req.method === "GET" && path === "/rsvps") {
        return sendJSON(res, 200, { responses: await listRSVPs(
          admin, decoded, String(req.query.clubID || ""), String(req.query.meetingID || "")
        ) });
      }
      if (req.method === "GET" && path === "/subscription") {
        return sendJSON(res, 200, await subscriptionStatus(admin, decoded.uid));
      }
      if (req.method === "POST" && path === "/subscription/rotate") {
        return sendJSON(res, 200, await rotateSubscription(admin, decoded.uid));
      }
      if (req.method === "POST" && path === "/subscription/revoke") {
        return sendJSON(res, 200, await revokeSubscription(admin, decoded.uid));
      }
      if (req.method === "PUT" && path === "/notifications/device") {
        return sendJSON(res, 200, await registerDevice(admin, decoded, req.body));
      }
      if (req.method === "DELETE" && path === "/notifications/device") {
        return sendJSON(res, 200, await unregisterDevice(admin, decoded, req.body));
      }
      if (req.method === "POST" && path === "/notifications/seen") {
        return sendJSON(res, 200, await acknowledgeNotification(admin, decoded, req.body));
      }
      if (req.method === "GET" && path === "/notifications/read-state") {
        return sendJSON(res, 200, await notificationReadStates(admin, decoded));
      }
      throw new HttpError(404, "Endpoint not found.");
    } catch (error) {
      const status = error instanceof HttpError ? error.status : 500;
      if (status === 500) console.error("PHS API request failed", { path: req.path, method: req.method, error });
      return sendJSON(res, status, { error: status === 500 ? "The request could not be completed." : error.message });
    }
  };
}

function calendarFeedHandler(admin) {
  return async (req, res) => {
    if (req.method !== "GET") return res.status(405).set("Allow", "GET").end();
    try {
      const result = await getCalendarResponse(admin, String(req.query.token || ""), req.headers);
      if (result.status === 404) return res.status(404).set("Cache-Control", "private, no-store").end();
      if (result.status === 503) return res.status(503).set({
        "Cache-Control": "private, no-store",
        "Retry-After": String(result.retryAfter || 5),
      }).end();
      const headers = {
        "Cache-Control": "private, no-store",
        "Content-Type": "text/calendar; charset=utf-8",
        ETag: `"${result.cache.etag}"`,
        "Last-Modified": new Date(result.cache.builtAt * 1000).toUTCString(),
        "X-Calendar-Cache": result.cacheHit ? "hit" : "miss",
      };
      if (result.status === 304) return res.status(304).set(headers).end();
      return res.status(200).set(headers).send(result.cache.body);
    } catch (error) {
      console.error("Calendar feed build failed", { error });
      return res.status(503).set({
        "Cache-Control": "private, no-store",
        "Retry-After": "30",
      }).end();
    }
  };
}

module.exports = { apiHandler, calendarFeedHandler };
