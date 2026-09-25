# PHS Connect data editing guide

Firebase Realtime Database is authoritative. The app may keep local files so screens open quickly, but those files are copies. Use the app or its authenticated backend functions for routine edits: one action may need to update several paths together.

| Data | Authoritative location | How to edit it |
| --- | --- | --- |
| Public club details and chat settings | `/clubs/{clubID}` | Club editor or approved chat controls. `lastUpdated` lets devices refresh changed clubs. |
| Approved members and leaders | `/clubMemberships/{clubID}/{uid}` | Club member editor or membership actions. The backend also maintains `/userClubMemberships/{uid}/{clubID}` so a student can find their clubs quickly. Do not hand-edit only one side. |
| Pending requests | `/clubJoinRequests/{clubID}/{uid}` | Membership actions. A pending request does not grant access. |
| Meeting bodies | `/clubMeetings/{clubID}/{meetingID}` | Meeting editor. Each occurrence has a permanent `meetingID`; recurring occurrences share a `seriesID`. |
| Meeting changes and month lookup | `/clubCalendars/{clubID}` | Backend-generated index and cursor. Do not edit it separately from a meeting. |
| RSVP responses | `/meetingRSVPs/{meetingID}/{uid}` | RSVP controls. `/userRSVPIndex/{uid}` helps find a user's responses when access changes. |
| Calendar subscriptions | `/calendarSubscriptions/{uid}` and `/calendarTokens/{tokenHash}` | Subscription controls. Raw subscription links are private. |
| Notification devices and read state | `/notificationDevices/{uid}` and `/notificationReadState/{uid}` | Managed by the app and backend. |

`/internal` contains retry receipts, locks, notification jobs, expirations, and identity reconciliation records. They coordinate updates and should not be edited by hand. A lock appearing briefly when a calendar or club update runs is expected.

Some older records still contain `meetingTimes`, `leaders`, `members`, or other legacy fields under `/clubs`. These are retained historical data, not the source for current calendars or access. New public club records omit the roster arrays; the app fills those arrays only for screens that need to show a roster. The canonical meeting dates are `startUtc`/`endUtc` for timed events and `startDate`/`endDateExclusive` for all-day events, in `America/Chicago`. The older `startTime`/`endTime` strings exist in the current app's view model and API response for display.

For future changes, start with the authoritative path and its backend writer. Check every derived path and listener before changing the schema. Keep club discovery data, membership, meetings, RSVP, and notification read state separate so an edit in one area does not download the others.
