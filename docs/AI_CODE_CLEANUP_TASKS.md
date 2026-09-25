# PHS Connect AI Implementation Tasks

**Current status (2026-09-24):** The listed cleanup tasks are complete. At the owner's request, automated test suites and their target/script references have been removed. Test results and filenames below record historical verification; they are not current runnable commands. Future work requires its own scope and appropriate build/manual verification.

## What the AI needs to do

Work through this document one task at a time in priority order. For every task, the AI must:

1. Work only in `/Users/sharulshah/Documents/PHS-Connect-Development`.
2. Read `AGENTS.md`, use the codebase-memory graph first, verify graph coverage, and inspect the current source before editing.
3. Recheck `git status` and preserve every existing user change; never revert or overwrite unrelated work.
4. Make only the scoped change described by the selected task and keep the implementation small, direct, and consistent with the style of earlier PHS Connect commits.
5. Preserve existing UI, navigation, chat behavior, notification preferences, discovery behavior, access rules, and other user-visible behavior unless the task explicitly says otherwise.
6. Do not deploy, run a live migration, mutate live Firebase data, or delete stored legacy Firebase data.
7. Treat the updated app and canonical v2 structures as the active implementation, while leaving inactive legacy data stored until a later explicitly authorized cleanup.
8. Add or update focused tests for the changed behavior, run the smallest relevant verification first, and run broader tests/builds when available.
9. Do not claim an iOS build or visual result was verified unless it actually ran on the requested tooling/device.
10. Stop and ask before making an additional user-visible product change or a consequential data-migration decision not covered here.
11. Finish each task with the files changed, tests run, unverified states, and any remaining risk.

Use this instruction with any task below:

> Inspect the current implementation before editing, preserve all uncommitted work and existing behavior, implement only this task, do not deploy or touch live data, leave stored legacy Firebase data untouched, add focused tests, and report exactly what changed and what remains unverified.

---

## P0 — Fix before release

### P0-01 — Repair the calendar cache manifest model

- [x] `CalendarCacheManifest` in `User With Tasks/Calendar/CalendarDataStore.swift:15` lacks `lastSuccessfulSync`, although later code reads and writes it.

**Task prompt:** Add a backward-decodable optional `lastSuccessfulSync` field to `CalendarCacheManifest`, preserve schema-v2 files that omit it, and add focused cache decoding tests for old, current, missing, and corrupt manifests.

### P0-02 — Fix the undefined membership identity predicate

- [x] `membershipAction` in `functions/lib/membership-service.js:339` invokes `isVerifiedSchoolEmail`, while the imported implementation is `isEligibleDecodedIdentity`.

**Task prompt:** Replace the undefined membership identity predicate with the canonical eligibility helper and directly test join, request, cancellation, and leave for verified, unverified, unsupported, and super-admin identities.

### P0-03 — Import Node crypto in the meeting service

- [x] `functions/lib/meeting-service.js` calls `createHash` and `randomUUID` without requiring Node's crypto module.

**Task prompt:** Import Node crypto explicitly in `meeting-service.js` and add tests that execute new-meeting saves, visibility-email resolution, edits, and deletes so missing runtime imports cannot escape again.

### P0-04 — Export the meeting notification formatter

- [x] `functions/index.js:15` imports `formatMeetingTime`, but `functions/lib/notifications.js` omits it from `module.exports`.

**Task prompt:** Export `formatMeetingTime` from `notifications.js` and test timed and multiday all-day notification formatting through the same exported surface used by `index.js`.

### P0-05 — Remove crash-prone club force unwraps

- [x] `MeetingInfoView.swift:48` and `MeetingView.swift:47` force-unwrap repeated club lookups and can crash when a meeting outlives its locally available club record.

**Task prompt:** Resolve the meeting's club once without force unwraps, render a neutral fallback or omit the orphaned meeting safely, and test deletion/access-loss races without changing normal styling.

### P0-06 — Reuse meeting operation IDs across retries

- [x] `deleteMeeting` and `saveMeetings` in `FirebaseDataFunctions.swift` create fresh UUIDs for every attempt, so retrying after an ambiguous timeout can duplicate a committed operation.

**Task prompt:** Generate one operation ID per user save/delete intent, retain it across ambiguous retries until backend confirmation or explicit cancellation, consume the canonical saved/deleted response, and test response-loss retries for duplicate prevention.

**Completed verification:** Added view-owned `MeetingMutationIntent`, threaded it through meeting mutation helpers and editor/detail/drag callers, and applied canonical responses in `CalendarDataStore`. Added Swift intent tests and backend create/edit/delete response-loss replay tests. After any ambiguous failure, later rejection responses also retain the ID because they cannot disprove an earlier commit; first-attempt validation rejection allows corrected input. Xcode 27/iOS 27: 3 intent tests pass; Node 22: all 76 backend tests pass. No live data or deployment changes. Visual and real network-loss flows remain unverified; pending intents are retained for the presentation lifetime, not across process termination.

### P0-07 — Reject stale RSVP completions

- [x] `MeetingRSVPModel` in `MeetingRSVPView.swift:130` does not bind network and disk completions to the initiating UID, Firebase project, club, and meeting.

**Task prompt:** Capture UID, Firebase project, club ID, meeting ID, and request generation at RSVP request start; reject stale completions before memory or disk mutation; clear prior leader results during reload; and test account switching and rapid meeting switching.

**Completed verification:** Updated `MeetingRSVPView.swift` with captured request contexts, guarded actor disk commits, account/teardown invalidation, and cleared leader state on reload. Added `MeetingRSVPModelTests.swift`; all 4 race tests pass on Xcode 27/iOS 27. Authenticated visual/device flows remain unverified; no live data changed.

### P0-08 — Preserve notification preferences for reactions

- [x] The reaction notification handler in `functions/index.js:117` bypasses the canonical muted-thread decision and reuses the original message revision, which can suppress valid later reactions as already read.

**Task prompt:** Route reaction eligibility through `shouldNotifyChat`, preserve all/thread/none/mentions behavior, define a stable monotonic reaction identity that works with read-before-send suppression, and add muted-thread, delayed-reaction, and already-seen tests.

**Completed verification:** Routed the reaction trigger through a testable handler in `functions/lib/notifications.js` and canonical `shouldNotifyChat`; reactions carry stable event-time/ID revisions. Chat acknowledgments preserve the highest message cursor while advancing `seenAt`, and iOS notification presentation/removal understands reaction timestamps. Updated `functions/index.js`, notification client/handler, and focused backend/Swift tests. Node 22: all 80 tests pass; Xcode 27/iOS 27: reaction decoder test passes. Live APNs, suspended-device timing, and visual flows remain unverified; no deployment or live writes.

### P0-09 — Manage chat observer lifecycles and bound startup queries

- [x] `setupMessagesListener` in `ChatView.swift:2165` creates multiple observers without retaining their handles, and the `childChanged` query can initially download all messages.

**Task prompt:** Introduce a small per-chat observer-handle record, bound changed-message startup to the saved cursor, detach observers on membership loss/account switch/view teardown, treat missing pinned data as an empty list, and test repeated setup plus account switching.

**Completed verification:** Added `ChatObserverRegistry.swift` and integrated handle ownership, scoped callback guards, membership/account/teardown detachment, pending-removal cancellation, and missing-pin clearing in `ChatView.swift`. Added/changed-message queries share the inclusive cached cursor (or a 100-message cold window). `ChatObserverRegistryTests.swift`: all 4 tests pass on Xcode 27/iOS 27. The existing broad direct-removal observer remains for compatibility with deletion writers lacking tombstones; P1-15 covers that writer issue, and P1-13 covers full cold metadata downloads. Live listener bandwidth, authenticated account switches, and visual flows remain unverified; no live writes.

### P0-10 — Keep calendar repair from deleting unrelated caches

- [x] `CalendarFileCache.load` in `CalendarDataStore.swift:109` can remove the entire UID/project directory, including RSVP and pending club-edit files, when the calendar manifest is corrupt.

**Task prompt:** Isolate calendar files beneath a calendar-specific subdirectory or delete only calendar-owned files during repair, preserve RSVP and club-edit data, and test manifest corruption and partial-file corruption.

**Completed verification:** Restricted corrupt-manifest repair in `CalendarDataStore.swift` to `manifest.json`, `clubs/`, and `meetings/`; retained the v2 layout and added a temporary support-directory injection for tests. Added `CalendarCacheRepairTests.swift`: corrupt manifests and partial meeting-file corruption preserve RSVP, pending club edits, unrelated files, and healthy-club state. Both repair tests pass on Xcode 27/iOS 27. The full Swift target passes all 21 tests; the final P0-06 ambiguous-failure/access-rejection refinement separately passes all 3 intent tests. Backend verification for this batch: all 80 Node 22 tests pass. Project/scheme validation and `git diff --check` pass. No deployment or live-data changes; authenticated visual flows, live APNs/listener traffic, and actual network-loss behavior remain unverified.

### P0-11 — Exercise real mutation entry points in tests

- [x] The current backend tests do not directly execute `saveMeetings`, `deleteMeetings`, `membershipAction`, or the formatter export used by the meeting notification handler.

**Task prompt:** Add focused service tests that execute meeting save/delete, membership actions, formatter export, visibility resolution, operation replay, and notification-job creation rather than testing only helpers.

**Completed verification:** The focused service suites now import and execute the exported `saveMeetings`, `deleteMeetings`, `membershipAction`, and `formatMeetingTime` surfaces directly. They cover create/edit/delete mutations, the full membership-action identity matrix, timed and multiday formatting, visibility-email resolution, canonical operation replay after response loss, and created/updated notification jobs. The complete Node 22 backend suite passes all 80 tests. No deployment or live Firebase data changes were made.

---

## P1 — High-value efficiency and correctness

### P1-01 — Stop eagerly syncing every calendar for super admins

- [x] `ContentView.swift:657` gives every club to `configureAdministrativeClubs`, causing broad calendar work even when the super admin has not opened those clubs.

**Task prompt:** Keep joined/led calendars continuously synchronized, but make super-admin access to unjoined clubs lazy and scoped to the opened editor/detail screen, cancelling it when that screen closes.

**Completed verification:** Removed the app-wide super-admin calendar configuration and added reference-counted administrative access leases scoped to club details, meeting details, and meeting editors. Opening the first eligible screen attaches and synchronizes only that unjoined club; nested screens share the lease, and closing the final screen detaches its cursor observer, cancels its sync work, and clears its calendar/access cache. Joined and led clubs remain driven by the membership observer. Four focused lifecycle tests and the complete Xcode 27 iOS suite pass (25 tests). No deployment or live Firebase data changes were made.

### P1-02 — Remove per-member cursor fanout

- [x] `appendMembershipCursors` in `meeting-service.js:243` produces O(member-count) writes for every calendar edit.

**Task prompt:** Stop copying meeting cursors into every membership record; authorize compact per-club `clubCalendars/{clubID}/latestChange` reads for eligible members/admins, observe one scalar per joined club, and add rules and delta-sync tests.

**Completed implementation:** `functions/lib/meeting-service.js`, `meeting-visibility.js`, and `membership-service.js` now publish/read the shared club cursor without copying it into membership records. `database.rules.json` permits only the scalar read for canonical members/leaders with matching verified email, while preserving existing super-admin authority and denying calendar bodies and client writes. `CalendarDataStore.swift` and the new `CalendarCursorRegistry.swift` maintain one scalar observer per joined/led club or open administrative scope, ignore stored membership cursors, detach on access/account teardown, and reject callbacks from detached observers. Role changes still require a snapshot.

**Verification:** Updated `functions/test/meeting-service.test.js`, `membership-service.test.js`, and `database-rules.test.js`; added `PHS Connect DevTests/CalendarCursorRegistryTests.swift`. The 32 focused backend tests, all 81 backend tests on Node 22, all 8 local Firebase rules tests, 3 focused cursor lifecycle tests, and all 28 iOS tests on Xcode 27 / iPhone 17 iOS 27 pass. Tests cover identical mutation path counts with 1 and 1,000 members, snapshot/edit/cancellation deltas, pagination, unchanged cursors without body reads, membership revocation, identity mismatch, and private-parent denial. Graph coverage was checked; reported Swift parse gaps were inspected directly. `git diff --check` passes.

**Unverified / rollout risk:** Authenticated multi-device UI and deployed rules/functions were not tested. No deployment, migration, or live Firebase changes occurred; stored legacy data is untouched. A later authorized rollout must make the scalar rules and updated client available before retiring membership cursor publication; older clients that depend on membership cursor changes will no longer receive that trigger.

### P1-03 — Bound historical calendar synchronization

- [x] `defaultRange` in `CalendarDataStore.swift:788` merges an old requested month with the rolling range and can permanently expand synchronization across many years.

**Task prompt:** Represent the rolling calendar range separately from bounded historical segments, sync only requested segments, retain cached history, and test far-past browsing followed by normal launch.

**Completed implementation:** `CalendarDataStore.swift` now plans a fixed rolling window independently from requested out-of-window months. Each requested month is stored as its own bounded cache segment with its own cursor and meeting IDs; rolling refreshes replace only rolling files, retain historical segments across relaunches, and never inherit an old requested date. Partially overlapping boundary months load as complete bounded months. Existing schema-v2 club states decode with an empty historical-segment list, corrupt-file repair covers every segment, and a role change clears meetings cached under the prior access level.

**Verification:** Added `CalendarHistoricalRangeTests.swift` and extended the manifest/repair tests. Ten focused cache tests passed before the boundary correction, the final four range tests passed afterward, and the final full Xcode 27 suite passed all 33 tests on an iPhone 17 iOS 27 simulator. Tests cover a 2018 request from a 2026 rolling window, exact one-month bounds, boundary-month coverage, relaunch followed by rolling refresh, retained historical meetings, old manifest decoding, cache repair, and role downgrade cleanup. Graph coverage was checked and the reported sync-task parse ranges were read directly. `git diff --check` passes.

**Unverified / remaining risk:** No authenticated end-to-end calendar browsing or live backend request was run, and no deployment or live Firebase data change occurred. Xcode reported one internal QoS priority-inversion runtime diagnostic while the otherwise passing suite ran.

### P1-04 — Index multiday meetings on every overlapping day

- [x] `CalendarMeetingIndex.swift` assigns every event only to its first day and repeatedly creates/parses dates during sorting.

**Task prompt:** Expand timed and all-day meetings across each overlapping Chicago calendar day with exclusive all-day ends, deduplicate occurrences, use a shared cached date-only formatter, and test overnight, multiday, DST, and month-boundary events.

**Completed implementation:** `CalendarMeetingIndex.swift` now deduplicates each club/meeting occurrence, parses its start once, sorts the precomputed records deterministically, and indexes it on every Chicago calendar day overlapped by its half-open interval. Timed meetings ending exactly at midnight do not spill into the next day, and all-day `endDateExclusive` remains exclusive. Month counts use the same expanded day set. `DateHandlingFunctions.swift` now provides a thread-cached Chicago date-only formatter, which the index and `dateForMeeting` share.

**Verification:** Added `CalendarMeetingIndexTests.swift`. All 5 focused tests and the full 38-test Xcode 27 suite pass on an iPhone 17 iOS 27 simulator. Coverage includes multiday all-day meetings, exclusive all-day ends, overnight timed meetings, exact-midnight ends, Chicago spring DST traversal, a January-to-February boundary, duplicate occurrences, cancellation filtering, and per-day counts. Graph coverage was checked; the unrelated reported sync-task parse ranges in `CalendarDataStore.swift` were read directly. `git diff --check` passes.

**Unverified / remaining risk:** The expanded events were not visually inspected in the authenticated week/month calendar UI. No deployment or live Firebase data change occurred.

### P1-05 — Stop rereading the full calendar cache after each mutation

- [x] `applySnapshot`, `applyDelta`, and `removeClub` in `CalendarDataStore.swift` call `load()` after mutations, rereading all account calendar files.

**Task prompt:** Keep the actor's current snapshot in memory, apply targeted mutations, stage snapshot replacements before swapping them atomically, commit cursors only after durable writes, evict stopped-session cache actors, and remove or consume the unused `repairedClubIDs` result.

**Completed implementation:** `CalendarFileCache` now hydrates its manifest, meeting map, and club files once per actor, returns snapshots from that actor-owned state, and updates only the affected club after snapshot, delta, access, and removal mutations. Snapshot and delta bodies are encoded before any replacement begins, each file replacement remains atomic, the manifest cursor is written only after all required body writes succeed, and actor memory is swapped only after that durable manifest commit. Stale files are removed afterward. The global cache registry was removed, so stopping a `CalendarDataStore` session releases its cache actor once outstanding work ends. The unused `repairedClubIDs` result was removed; relaunch repair still resets only affected manifest state and preserves unrelated cache data.

**Verification:** Added `CalendarCacheMutationTests.swift` to prove snapshot, delta, removal, and later `load()` calls perform one initial disk hydration, and to prove a staged encoding failure leaves both actor memory and the durable cursor/body unchanged. Existing repair tests now open a fresh cache actor before simulating relaunch repair. All 13 focused cache tests and the full 40-test Xcode 27 suite pass on an iPhone 17 iOS 27 simulator. Graph coverage was checked; the reported partial ranges are limited to the separately scheduled sync-task guards and were read directly. Searches confirm that mutation paths no longer call `load()`, the cache registry and `repairedClubIDs` are gone, and `git diff --check` passes.

**Unverified / remaining risk:** No process-kill fault injection was performed between individual durable writes and the manifest commit. No deployment or live Firebase data change occurred. Xcode reported one internal QoS priority-inversion runtime diagnostic while the otherwise passing full suite ran.

### P1-06 — Prevent stale sync tasks from committing

- [x] `scheduleSync` in `CalendarDataStore.swift:613` cannot stop a superseded same-account task after it begins a cache-actor mutation.

**Task prompt:** Assign a per-session/per-club sync generation and have the cache actor validate it immediately before file and manifest commits so stale requests cannot overwrite newer results.

**Completed implementation:** Each scheduled club sync now advances a per-club generation inside the current `CalendarDataStore` session. `CalendarFileCache` records only the newest session/club generation and rejects older registrations. Snapshot, delta, and access-loss removal paths yield and validate both task cancellation and that exact generation immediately before every meeting-body write and manifest commit. The main actor repeats the generation check before applying returned snapshots, while membership loss and administrative-scope removal invalidate the outstanding club generation. This stays within the existing store and cache actor rather than adding another registry or coordination type.

**Verification:** Extended `CalendarCacheMutationTests.swift` to prove a superseded club generation cannot write a body or cursor, the current generation can commit, and an older session cannot reclaim the club even with a larger club-local number. All 9 focused cache/range tests and the full 41-test Xcode 27 suite pass on an iPhone 17 iOS 27 simulator. Graph coverage was checked; every reported partial sync-guard range was read directly. `git diff --check` passes.

**Unverified / remaining risk:** No process-level kill was injected in the narrow interval after the final generation check and before the atomic filesystem call. No deployment or live Firebase data change occurred. Xcode reported its existing internal QoS priority-inversion runtime diagnostic while the otherwise passing full suite ran.

### P1-07 — Filter calendar changes before reading bodies

- [x] `syncClubCalendar` in `meeting-service.js:602` performs sequential meeting-body reads that are unnecessary for tombstones and out-of-range changes.

**Task prompt:** Filter change records by operation and date-range metadata first, emit tombstones without body reads, fetch only required upsert bodies with bounded concurrency, and prove unchanged/deleted/out-of-range deltas read zero bodies.

**Completed implementation:** `syncClubCalendar` now collapses each page as before, emits delete/cancel tombstones directly from change metadata, and converts metadata-confirmed out-of-window upserts into delete tombstones without loading their meeting records. Only potentially visible in-window upserts read canonical bodies. Those reads run in stable batches of eight, and results are written back to their original collapsed positions so response ordering remains deterministic. Missing legacy range metadata still falls back to a body read.

**Verification:** Added focused read instrumentation and tests covering unchanged cursors, delete tombstones, cancel tombstones, out-of-range upserts, and 20 required upserts. The first four cases perform zero `/clubMeetings` reads; the required bodies reach exactly eight concurrent reads and all 20 return in order. All 13 focused meeting/admin tests and the full 83-test backend suite pass under Node 22. Graph coverage reports no recorded gaps in the implementation or affected tests, and `git diff --check` passes.

**Unverified / remaining risk:** No deployed function or live Firebase data was exercised or changed.

### P1-08 — Stop the next-meeting preview after the first valid result

- [x] `nextPublicMeeting` in `meeting-service.js:591` loads the full one-year candidate range and all bodies before selecting one unrestricted meeting.

**Task prompt:** Walk month indexes chronologically, fetch candidates in start order, stop after the earliest valid unrestricted meeting is known, preserve overlap handling, and measure meeting-body reads.

**Completed implementation:** `nextPublicMeeting` now walks the existing monthly indexes from the current Chicago month through the one-year horizon. It loads at most one month's unseen bodies at a time in the existing 25-record batches, sorts those candidates by their actual start epoch with a deterministic ID tie-break, validates overlap against that month's bounded window, and returns the first non-cancelled public future meeting. IDs are deduplicated only after their body truly overlaps the visited month, so a stale early index entry cannot suppress the record in its correct later month. The function stops before reading any later month once the earliest valid candidate is known.

**Verification:** Added a dynamic-date test with hidden, later, and multimonth candidates in deliberately nonchronological index order. It returns the overlapping earliest public meeting, reads only the three bodies in the decisive month, and performs no index or body read for the following month. All 14 focused meeting/admin tests and the full 84-test backend suite pass under Node 22. Graph coverage reports no recorded gaps in the implementation or affected calendar helpers/tests, and `git diff --check` passes.

**Unverified / remaining risk:** No deployed preview endpoint or live Firebase index was exercised or changed.

### P1-09 — Reuse meeting visibility and membership work

- [x] `saveMeetings` repeatedly resolves identical visibility emails and revalidates RSVP access for every occurrence even when access did not change.

**Task prompt:** Resolve unique visibility emails once per request, reuse a bounded membership snapshot, run RSVP revalidation only when club/visibility/cancellation changes, and preserve per-occurrence IDs and responses.

**Completed implementation:** Repeated visibility emails in one save request share the same in-flight Auth lookup. Existing occurrences revalidate active RSVPs only when their club, effective visibility, or cancellation state changes; all access-changing occurrences in a club share one membership snapshot. New occurrences and title-only edits skip those RSVP and roster reads. Per-occurrence IDs and save responses remain unchanged.

**Verification:** A two-occurrence series test confirms one Auth lookup, one membership read, and one RSVP read per affected occurrence while preserving both IDs and active responses. The create/edit/delete test confirms no roster reads for a create or title-only edit and continued RSVP invalidation on cancellation. All 15 focused meeting/admin tests and the full 85-test backend suite pass under Node 22; `git diff --check` passes. The graph coverage request was blocked by automatic usage review, so the affected source and call sites were checked directly.

**Unverified / remaining risk:** No deployed function or live Firebase data was exercised or changed.

### P1-10 — Use acknowledgment responses instead of another full read-state fetch

- [x] `NotificationRegistrationManager.acknowledge` ignores the returned state and immediately requests the complete read-state collection, while background sync pushes also ignore the state included in their payload.

**Task prompt:** Return and decode the saved state key/type/revision, merge it monotonically into local state, remove only matching delivered notifications without another GET, retain full reconciliation for foreground activation, and move registration lookup after a committed backend transaction.

**Completed implementation:** The acknowledgment response now includes the saved scope key and state. The iOS manager merges that state into its local read map, preserves the newer message or meeting revision and reaction watermark, and removes only delivered notifications covered by that scope. Background sync pushes carry the same key, revision, and watermark; older payloads still use full reconciliation. Foreground activation continues to fetch the complete collection. The backend reads device registrations and sends a sync push only after a committed state transaction.

**Verification:** A backend test confirms the saved key and revision are returned and an unchanged meeting acknowledgment performs no registration lookup. All 14 focused notification tests and the full 86-test backend suite pass under Node 22. The iPhone 17 iOS 27 simulator suite passes 41/41, and a final Xcode 27 build after the last source edit succeeds. `git diff --check` passes. The codebase graph coverage call was blocked by automatic usage review, so the relevant source and call sites were checked directly.

**Unverified / remaining risk:** Cross-device push delivery and authenticated notification UI were not exercised end to end. No backend deployment or live Firebase data change occurred.

### P1-11 — Avoid pruning notification state on every new scope

- [x] `pruneReadState` in `notifications.js:297` queries up to 525 records whenever a new thread or meeting read scope is created.

**Task prompt:** Add a simple low-write prune cadence or threshold hint so new scopes do not run the 525-record query every time, keep the hard bound, and test monotonic state and concurrent acknowledgments.

**Completed implementation:** A per-user internal counter schedules a bounded prune on the first new scope and each following group of 25. One leased request per user performs the prune; scopes acknowledged during that request trigger a final pass before release. Each pass retains at most 475 recent states, leaving room for the next 25 scopes without a collection query. Existing-scope acknowledgments do not advance the counter. Account-deletion and invalid-identity cleanup remove the hint with read state.

**Verification:** The focused notification suite passes 15/15 and the full Node 22 backend suite passes 87/87. Tests cover the 25-scope cadence, 600 concurrent new acknowledgments settling at no more than 500 states without overlapping prune storms, and monotonic revisions for one scope. `git diff --check` passes. The codebase graph remained unavailable due automatic usage review, so affected source and cleanup paths were inspected directly.

**Unverified / remaining risk:** Cross-process Firebase transaction timing and live notification delivery were not exercised. No deployment or live Firebase data change occurred.

### P1-12 — Reduce feed-token and cache-retention reads

- [x] `resolveToken` reads several subscription scalars, and feed cache cleanup reads the entire cache parent including calendar bodies.

**Task prompt:** Make the atomically maintained token record authoritative for generation/revocation where safe, continue validating Auth/access before cache or 304 responses, and remove deterministic expired day keys without downloading cached feed bodies.

**Completed implementation:** Feed token lookup now trusts the token's atomically maintained `valid` flag and UID, removing three subscription-scalar reads per request. Auth eligibility and club membership/dependency validation still precede cached responses and 304s. A small `cacheDays` list tracks at most the current and two prior calendar days; cold builds remove expired day paths in the same update as the new cache. The first build after this change replaces any untracked legacy cache without reading its bodies. Token rotation, revocation, and identity invalidation clear the day list with the cache.

**Verification:** Four focused feed tests and the full 90-test Node 22 backend suite pass. Tests cover warm and conditional responses without redundant token reads, immediate rejection of a revoked token, replacement of an untracked legacy cache, and deterministic expiry of tracked days without a cache-parent/body read. `git diff --check` passes. The codebase graph remained unavailable due automatic usage review, so token mutation and cleanup paths were inspected directly.

**Unverified / remaining risk:** Deployed feed requests and live Firebase cache contents were not exercised or changed. Existing token records rely on all runtime rotation/revocation/identity paths continuing to update the token validity atomically with subscription state.

### P1-13 — Stop cold chat loads from downloading complete histories

- [x] `fetchChatsMetaData` in `FirebaseDataFunctions.swift:611` downloads whole chats, while `loadChats` in `ChatView.swift:2034` has duplicate loops and nested queue/MainActor/task transitions.

**Task prompt:** Fetch only scalar chat metadata plus a bounded recent-message page, page older history on demand, deduplicate chat IDs with a Set, flatten the concurrency flow, and preserve existing chat UI and ordering.

**Completed implementation:** Cold chat fetches now read `clubID`, `pinned`, and only the latest 100 messages ordered by the existing `lastUpdated` index, then restore the established date ordering for rendering. Chat IDs are deduplicated before reads. `loadChats` uses one task and the existing serial cache queue for file reads; it fetches any missing cache files once and checks the account/load generation before applying either stage. The conversation adds a “Load earlier messages” control that pages 100 earlier records using the timestamp and message ID boundary, merges by ID, and retains the existing render/index/cache path.

**Verification:** The modified app builds on Xcode 27, and the complete iPhone 17 iOS 27 simulator suite passes. `git diff --check` passes. The codebase graph remained unavailable due automatic usage review, so the fetch, listener, cache, and view paths were inspected directly.

**Unverified / remaining risk:** Authenticated chat scrolling and Firebase paging were not exercised end to end. On a first install, a thread with no message in the latest page becomes visible after paging to one of its messages because the current schema has no separate thread-name index. No deployment or live Firebase data change occurred.

### P1-14 — Remove the unused `lastMessage` copy

- [x] `sendMessage` reads the complete chat and maintains `/lastMessage`, but the current app and Functions backend do not consume that node for behavior.

**Task prompt:** Reverify current consumers, then remove the unused `Chat.lastMessage` property, read/write maintenance, and rules while leaving existing Firebase values untouched; ensure chat ordering continues using loaded messages.

**Completed implementation:** Removed the unused `Chat.lastMessage` model field, the complete-chat read and mirrored write after sending a message, the last-message read/cleanup during deletion, and its client write rule. Chat ordering continues to compare messages already loaded in `sortedTopChats`. Existing stored `/lastMessage` values are untouched.

**Verification:** Targeted source search found no remaining app, Functions, or rules consumer of the node. The database rules parse as JSON, the full Xcode 27 iPhone 17 simulator suite passes, and `git diff --check` passes. The codebase graph remained unavailable due automatic usage review, so relevant source and rules were checked directly.

**Unverified / remaining risk:** No authenticated chat ordering or live Firebase write was exercised. No deployment or live Firebase data change occurred.

### P1-15 — Delete threads through the indexed query and emit deletion records

- [x] `removeThread` in `FirebaseDataFunctions.swift:834` scans all messages, deletes matching children without `deletedMessages` entries, and can leave pinned/sidebar state inconsistent.

**Task prompt:** Use the existing indexed `threadName` query, atomically delete returned messages while writing `deletedMessages` records and fixing pinned state, and test offline clients plus deletion of the newest thread message.

**Completed implementation:** Thread deletion now queries only the selected `threadName` through the existing index. One chat-root update removes the matching messages, writes a timestamped `deletedMessages` record for each ID, and removes those IDs from pinned state. The existing deletion observer therefore removes the messages from local/sidebar state, including when a client reconnects after being offline.

**Verification:** Two focused Xcode 27 simulator tests pass for the atomic update payload, including the newest message and pinned cleanup. All nine local Firebase rules tests pass; the new emulator test disconnects its reader between the initial state and a multi-path deletion, then confirms the indexed deletion records, retained unrelated message, and pins are visible on return. `git diff --check` passes. The codebase graph remained unavailable due automatic usage review, so the query, observer, rules, and test paths were inspected directly.

**Unverified / remaining risk:** A live authenticated chat and a genuinely disconnected device were not exercised. No deployment or live Firebase data change occurred.

### P1-16 — Scope private chat caches by project and account

- [x] `ChatCache` and deletion cursors live in Documents without Firebase project or UID scoping, while several chat indices use separator-encoded AppStorage strings.

**Task prompt:** Move private chat files and cursors to Application Support v2 scoped by project and UID, use atomic writes and Codable sets/dictionaries, migrate or safely discard old cache files, and clear private memory/listeners on account change.

**Completed implementation:** Chat files and one Codable local-state file now live under a hashed Firebase project/UID directory in Application Support v2. Chat filenames are also derived from chat IDs, and both files use atomic writes. The local state replaces separator-encoded AppStorage chat IDs/read markers and includes deletion cursors. On a scoped session start, the app discards old unscoped Documents chat/cursor files and clears the obsolete UserDefaults keys; it never imports legacy private data into a different account. Account/project session reset reloads only the matching state and clears chat memory and observers. The existing serial cache queue orders state reads and writes across rapid switches.

**Verification:** Two focused cache tests prove project/account isolation, Codable round-tripping with separator-bearing thread names, and legacy cleanup without touching unrelated files. The full Xcode 27 iPhone 17 simulator suite passes 45 tests, and `git diff --check` passes. The codebase graph remained unavailable due automatic usage review, so cache and account-lifecycle call sites were checked directly.

**Unverified / remaining risk:** No authenticated multi-account device session or real legacy-file migration was exercised. Legacy unscoped cache content is deliberately discarded on upgrade, so first launch for each account refetches chat data. No deployment or live Firebase data change occurred.

### P1-17 — Remove unused chat fields and the typing listener

- [x] `Chat` contains unused `directMessageTo`, `typingUsers`, `edited`, and `mentions` fields, and each active chat observes `typingUsers` despite having no writer or UI consumer.

**Task prompt:** Verify current graph and textual references, remove unused model fields/parameters and the typing observer/rule, leave stored legacy values untouched, and preserve the notification-mode enum without adding mention behavior.

**Completed implementation:** Removed the four unused model fields, the always-nil group-chat creation parameter, the typing observer, and the typing write rule. Existing Firebase fields remain stored and are ignored by decoding. The notification-mode enum, including `mentions`, and its current backend behavior are unchanged.

**Verification:** Targeted source search found no remaining active consumers of the removed fields. Three focused iOS cache/decode tests pass, including a legacy chat fixture with all four removed fields. All nine local Firebase rules tests pass, including a new assertion that typing writes are denied. `git diff --check` passes. The codebase graph remained unavailable due automatic usage review, so the relevant app, backend, and rules references were checked directly.

**Unverified / remaining risk:** No live chat listener or deployed rules were exercised. No deployment or live Firebase data change occurred.

### P1-18 — Make reaction mutation concurrency-safe

- [x] `updateMessageReaction` replaces an entire emoji user-ID array and can lose simultaneous reactions from separate devices.

**Task prompt:** Preserve the current reaction schema and UI while using a transaction on the emoji's user-ID array, or migrate to a UID-keyed map only if demonstrably simpler, and test simultaneous add/remove operations.

**Completed implementation:** All reaction controls now send the signed-in user's add/remove intent rather than a copy of the whole emoji array. `updateMessageReaction` applies that intent in a Firebase transaction at the existing emoji array node, preserving concurrent changes and making duplicate same-user intents idempotent. It advances `lastUpdated` after the committed transaction so existing message listeners still receive reactions on older messages. The stored array schema and UI remain unchanged.

**Verification:** Two focused Swift tests cover interleaved add/add and remove/add intents. A local Firebase emulator test performs concurrent transactions from separate authorized clients and confirms both additions and the later remove/add survive; all 10 rules tests pass. The full Xcode 27 iPhone 17 simulator suite passes 48 tests, and `git diff --check` passes. The codebase graph remained unavailable due automatic usage review, so all reaction call sites and rules were inspected directly.

**Unverified / remaining risk:** A live simultaneous multi-device reaction was not exercised. The follow-up `lastUpdated` write is separate from the array transaction; if it fails, the reaction remains committed but an old message may await another refresh before appearing on another device. No deployment or live Firebase data change occurred.

### P1-19 — Update only missing profile fields during user initialization

- [x] `createUserNodeIfNeeded` reads `/users/{uid}` and can rewrite default favorites while filling a missing profile field.

**Task prompt:** Read only required profile scalars and update only missing owned fields, never rewrite favorites/preferences or legacy `fcmToken`, and test partial existing profiles.

**Completed implementation:** User initialization reads only `userID`, `userEmail`, `userImage`, `userName`, and `favoritedClubs` scalars, then updates only fields that are absent. It checks the authenticated UID again after the reads. Existing favorites are never overwritten; the historical `[""]` default is written only for a new or missing favorites field. Preferences and `fcmToken` are never included in the update.

**Verification:** Two focused Xcode 27 simulator tests pass for a partial profile and a new profile, proving the exact update keys and absence of preference/legacy-token writes. The app compiles, and `git diff --check` passes. The codebase graph remained unavailable due automatic usage review, so profile call sites and field rules were inspected directly.

**Unverified / remaining risk:** A simultaneous profile edit between the scalar reads and update was not exercised; the update targets only fields missing at read time. No live Firebase write or deployment occurred.

### P1-20 — Resolve announcement club names locally

- [x] `AnnouncementViews.swift` already receives the club collection but performs separate Firebase reads for missing club names.

**Task prompt:** Resolve club names from the supplied club collection, remove `getClubNameByID` if no callers remain, and retain the existing unknown-club fallback.

**Completed implementation:** Both announcement lists now resolve club names directly from their supplied clubs and render `Unknown Club` immediately when absent. The asynchronous per-row Firebase reads and their loading placeholders are gone, as is the now-unused `getClubNameByID` helper.

**Verification:** Targeted source search found no remaining call to the removed helper or `clubNames` state. The modified app builds on Xcode 27 / iPhone 17 iOS 27, and `git diff --check` passes. The codebase graph remained unavailable due automatic usage review, so the two view branches and helper call sites were inspected directly.

**Unverified / remaining risk:** Announcement screens were not visually inspected with an authenticated account. No live Firebase data change or deployment occurred.

### P1-21 — Use transactions for shared arrays

- [x] Favorites, announcement `peopleSeen`, and club `chatIDs` are downloaded, modified locally, and replaced, allowing concurrent-device updates to be lost.

**Task prompt:** Convert favorites, `peopleSeen`, and `chatIDs` mutations to focused RTDB transactions while preserving their current stored shape and UI behavior, and test concurrent devices.

**Completed implementation:** Favorites, announcement `peopleSeen`, and club `chatIDs` now use one focused array transaction helper at their existing nodes. Each transaction reapplies a unique append or removal to the latest server value and aborts a no-op. The existing array schema, favorites sentinel, local UI updates, and club `lastUpdated` behavior remain intact.

**Verification:** A focused Swift test passes for interleaved additions/removal and duplicate-add idempotence. A local Firebase emulator test performs simultaneous writes from separate authorized clients to all three arrays, then a concurrent favorites remove/add; all 11 rules tests pass. The app compiles on Xcode 27, and `git diff --check` passes. The codebase graph remained unavailable due automatic usage review, so all three mutations and rules were inspected directly.

**Unverified / remaining risk:** Authenticated multi-device UI was not exercised. No deployment or live Firebase data change occurred.

### P1-22 — Fetch leader RSVP profile names concurrently

- [x] `listRSVPs` in `meeting-service.js:709` performs one awaited user-name read after another.

**Task prompt:** Fetch only required profile names with bounded parallelism, keep response ordering deterministic, and test inactive historical responses and missing profiles.

**Completed implementation:** Leader RSVP listing computes access/active status first, then fetches only each returned user's `userName` scalar in batches of eight. Missing profiles retain the `Student` fallback, inactive historical rows remain visible, and final name sorting uses UID as a deterministic tie-breaker.

**Verification:** A 22-row test confirms exactly 22 scalar name reads, a maximum of eight simultaneous reads, stable ordering, inactive history, missing-profile fallback, and persisted access-loss invalidation. All 16 focused meeting/admin tests and the full 91-test Node 22 backend suite pass; `git diff --check` passes. The codebase graph remained unavailable due automatic usage review, so `listRSVPs` and its callers were inspected directly.

**Unverified / remaining risk:** No deployed leader RSVP endpoint or live Firebase data was exercised or changed.

### P1-23 — Expire completed operation and notification records

- [x] Completed `meetingOperations` and `meetingNotificationJobs` records are retained indefinitely.

**Task prompt:** Define a retry-safe retention window, add expiration indexes and scheduled bounded cleanup, retain completed idempotency receipts long enough for retries, and test that cleanup never causes duplicate committed meetings.

**Implemented:** New meeting operation IDs carry their issue time. Completed operations receive a 90-day expiration index, and completed notification jobs receive a 30-day expiration index. An hourly cleanup removes at most 200 expired records from each index per run. Reusing an expired timestamped operation ID is rejected before any meeting write, so cleanup cannot turn a retry into a duplicate meeting. Legacy operation IDs remain available to older app versions, with their receipts retained for retry safety.

**Verification:** The full Node 22 backend suite passes (93 tests), the local Firebase rules suite passes (11 tests), focused iOS operation-ID tests pass (3 tests), and `git diff --check` passes. Tests cover the retention boundary, bounded cleanup, legacy retries, and rejection of a cleaned-up operation ID without another meeting write. No deployed function or live Firebase data was changed.

### P1-24 — Simplify and correctly debounce Search filtering

- [x] `calculateFiltered` in `SearchClubView.swift:802` duplicates branches, chains multiple sorts, mutates loading state, and is called by multiple one-second timers and duplicate appearances.

**Task prompt:** Create one pure filter-and-priority comparator, replace repeated timers with one cancellable task-based debounce for text input only, remove duplicate lifecycle calls, and preserve favorites/leaders/members/name ordering.

**Implemented:** Filtering now uses one pure function and one priority comparator (favorite, leader, member, then ascending or descending name). Text input has one cancellable one-second task; genre, favorite, sort, and club updates refresh immediately. Removed duplicate appearance refreshes and timer-driven loading resets.

**Verification:** Both focused iOS filtering tests pass on Xcode 27/iOS 27. They cover priority in both name directions and text/genre matching across all existing fields. `git diff --check` passes. No visual interaction test or live data change was performed.

### P1-25 — Share one correct leader/member email parser

- [x] `addLeaderFunc` in `CreateClubView.swift:1024` has five delimiter branches, validates only the combined input, and incorrectly treats hyphens as separators.

**Task prompt:** Extract one small shared email parser used by leader and member editors, validate every normalized address independently, preserve Gmail and D214 acceptance plus the six-leader limit, and test display-name input and hyphenated addresses.

**Implemented:** Both club editors use a shared email parser for display-name entries and comma, semicolon, slash, or newline separated addresses. It normalizes case, checks each address against the Gmail and D214 domain rules, and keeps hyphens inside addresses. Leader addition deduplicates normalized addresses and enforces the six-leader limit for both single and bulk input.

**Verification:** Both focused iOS parser tests pass on Xcode 27/iOS 27, covering display names, mixed separators, hyphenated addresses, and independent validation of mixed valid/invalid input. `git diff --check` passes. The leader editor's button interaction was not visually exercised; no live data was changed.

### P1-26 — Remove development-specific backend URL fallbacks

- [x] `subscription-service.js` and `constants.js` embed Dev-specific project and hosting identifiers that could be carried accidentally into Official.

**Task prompt:** Derive project-specific URLs from verified runtime configuration, fail closed when required deployment metadata is absent, retain explicit emulator/test overrides, and prevent Dev identifiers from carrying into Official.

**Implemented:** Calendar subscription and meeting-link URLs are resolved from consistent `GCLOUD_PROJECT`, `GCP_PROJECT`, and `FIREBASE_CONFIG` project metadata when needed. Missing, conflicting, or invalid deployment metadata fails closed; subscription rotation resolves its URL before any database access. Explicit HTTPS overrides remain available with project metadata, while local HTTP overrides are restricted to emulator/test use. Firebase Hosting and Cloud Functions overrides that name another project are rejected. Removed embedded Dev project and Hosting identifiers from the deployed backend.

**Verification:** Focused runtime URL and calendar tests pass (20 tests). The full Node 22 backend suite passes (97 tests), local Firebase rules tests pass (11 tests), and the full Xcode 27/iOS 27 simulator suite passes (54 tests); `git diff --check` passes. Tests cover Official URL derivation, missing/conflicting metadata, local overrides, cross-project rejection, and rotation failure before database access. Default Hosting URL derivation assumes the standard project-ID site; a custom Hosting domain requires an explicit `MEETING_WEB_BASE`. No deployment or live Firebase data was changed.

---

## P2 — Lower-risk simplification and dead-code removal

### P2-01 — Remove the unused authenticated meetings-list route

- [x] `GET /meetings` and `listMeetings` duplicate the active delta-sync path and have no current app, test, script, or hosting caller.

**Task prompt:** Reverify all callers, then remove the unused `/meetings` route/import/export and `listMeetings` implementation while retaining `/calendar/sync` and next-public-meeting behavior.

**Implemented:** Removed the unused authenticated route and `listMeetings` implementation/export after checking app, hosting, script, test, and backend references. Calendar delta sync and next-public-meeting paths remain unchanged.

**Verification:** Focused API/meeting tests pass (19 tests), including a route test that confirms `/meetings` returns 404 while `/calendar/sync` still returns a delta. `git diff --check` passes. No deployed endpoint or live Firebase data was exercised.

### P2-02 — Move migration-only calendar code out of the deployed library

- [x] `functions/lib/legacy-calendar.js` is used by migration scripts and tests rather than deployed runtime handlers.

**Task prompt:** Move strict legacy conversion helpers beneath `functions/scripts/lib`, update migration and tests, ensure production imports do not reference them, and retain all one-time tooling for the Official-project handoff.

**Implemented:** Moved the unchanged legacy conversion logic to `functions/scripts/lib/legacy-calendar.js` and updated the migration, visibility-claims backfill, readiness validator, and test imports. Production `functions/lib` and `index.js` have no import of the moved module; the Firebase functions configuration already excludes `scripts` from deployment.

**Verification:** Focused legacy conversion, migration, readiness, and calendar tests pass (24 tests); `git diff --check` passes. No migration or live Firebase data was run or changed.

### P2-03 — Replace duplicated AddMeeting model construction

- [x] `addInfoToMeetingChild` and `addInfoToHelper` duplicate meeting field assignment, while preview rendering follows parallel branches.

**Task prompt:** Replace the two mutation helpers with one pure meeting builder used by preview and save, render the preview once, and preserve occurrence/series IDs and all-day semantics.

**Implemented:** One value-returning builder supplies both the preview and save path. Saving copies the original meeting so occurrence and series fields remain available; preview uses an unsaved base so opening its detail sheet does not trigger an RSVP lookup. Removed the duplicate field assignments, preview branches, and refresh state.

**Verification:** Both focused iOS builder tests pass on Xcode 27/iOS 27, covering all-day preview dates, title fallback, visibility, and unchanged original occurrence/series identity. `git diff --check` passes. The editor was not visually exercised or saved against live Firebase.

### P2-04 — Share the Markdown-editing helper

- [x] `AddMeetingView` and `AnnouncementViews` contain effectively identical Markdown style and link mutation functions.

**Task prompt:** Extract one small inout String/NSRange Markdown helper without creating a framework, retain existing alerts and selection clearing, and use it from both views.

**Implemented:** Added one `editMarkdown` helper to the existing Markdown utility file and changed both editors to call it for style toggles and links. Each view retains its current empty-selection alert and menu handling; valid selections are cleared by the helper.

**Verification:** Both focused iOS Markdown tests pass on Xcode 27/iOS 27, including UTF-16 emoji selection, style toggle, links, empty selection, and invalid range behavior. `git diff --check` passes. The editor interactions were not visually exercised.

### P2-05 — Share Firebase boolean normalization

- [x] `ChatView` and `Settings` contain identical 29-line `boolFromGlobalSetting` implementations.

**Task prompt:** Move Firebase boolean normalization to one short shared helper, cover Bool/NSNumber/Int/string/null values, and replace both copies.

**Implemented:** Moved `boolFromGlobalSetting` to the existing shared utility file and removed both view-local copies. The same true/false/string/null behavior remains at all three call sites.

**Verification:** The focused iOS normalization test passes on Xcode 27/iOS 27, covering Bool, NSNumber, Int, recognized strings, unknown strings, NSNull, and nil. `git diff --check` passes. Live RTDB snapshots were not exercised.

### P2-06 — Simplify PHSAPIClient generics

- [x] `PHSAPIClient.request` has an unused `response:` argument, an existential `AnyEncodable` wrapper, and a forced generic cast for empty responses.

**Task prompt:** Simplify the request API with safe generic body/response overloads or a dedicated no-content method, remove the unused argument and force cast, and update callers without changing authentication or error behavior.

**Implemented:** Replaced the existential request body and unused response type argument with typed body/response overloads. Three callers that discard a success response now use `requestNoContent`; removed `EmptyAPIResponse`, `AnyEncodable`, and the forced cast. Both APIs share the existing authentication, URL, HTTP status, and server-error path.

**Verification:** The Xcode 27/iOS 27 simulator app build passes, covering all updated call sites, and `git diff --check` passes. Authenticated network behavior was not exercised against a server; no live data was changed.

### P2-07 — Trim unused client DTO fields

- [x] The client decodes membership timestamps/hashes, request timestamps, `ownMembership`, several subscription timestamps, RSVP timestamps, and expanded notification-state metadata that it never consumes.

**Task prompt:** Trim only graph- and source-verified unused client DTO fields, rely on Decodable ignoring additional server fields, keep server authorization/audit metadata intact, and add decoding fixtures to prove compatibility.

**Implemented:** Removed unused client-only membership hash/timestamps/cursor, request timestamps, `ownMembership`, subscription timestamps/revocation flag, RSVP history timestamps/reasons, and notification descriptor fields. Retained membership `accessRevision`, RSVP `active`, and notification `seenAt`, which current behavior reads. Server records and authorization/audit data were not changed.

**Verification:** Two server-shaped iOS decoding fixture tests pass on Xcode 27/iOS 27, including extra access and RSVP fields; the app target compiles and `git diff --check` passes. Private subscription/notification DTOs were compile-verified but not exercised against a live backend. The codebase graph remained unavailable due automatic usage review, so targeted source search was used for field-use verification.

### P2-08 — Consolidate membership action wrappers

- [x] Join, leave, request, and cancellation wrappers repeat the same API/toast flow and accept email arguments they ignore.

**Task prompt:** Remove the ignored email parameters and route these actions through one private membership-action helper while preserving every public wrapper's exact success/error copy and callers.

**Implemented:** The four public membership wrappers now pass their action and original success/error titles through one private request/toast helper. Removed ignored email parameters and updated every ClubCard call site. Leader approval/rejection remains separate because it sends a target email and completion callback.

**Verification:** The Xcode 27/iOS 27 simulator app build passes and `git diff --check` passes. Authenticated join/leave/request UI flows were not exercised against a live backend; no live data was changed.

### P2-09 — Remove dead club-edit recovery state

- [x] `ClubEditUndoStore` never assigns `recoveredClub`, contains an empty `needsRecovery` branch, and persists an unused `submittedAt` value.

**Task prompt:** Remove only the dead recovery field, empty branch, unused timestamp, and corresponding `ClubInfoView` observer while preserving the persisted operation ID, retry scheduling, undo window, and photo cleanup.

**Implemented:** Removed `recoveredClub`, `needsRecovery`, its empty branch and assignments, the unused persisted `submittedAt`, and the ClubInfoView observer. The saved edit ID, retry timer, undo deadline, and photo paths remain intact.

**Verification:** The focused iOS archive compatibility test passes on Xcode 27/iOS 27: an older archive containing `submittedAt` still decodes, keeps the operation ID and uploaded paths, and re-encodes without the obsolete field. `git diff --check` passes. Crash recovery and live backend retry were not exercised.

### P2-10 — Simplify NotificationRegistrationManager state

- [x] `NotificationRegistrationManager` is never observed and every synchronization call uses the default `force: false`, leaving unused observation and force machinery.

**Task prompt:** Remove unnecessary `@Observable`, the unused force parameter/state, and duplicate delivered-notification filtering through one small helper while retaining the 24-hour throttle and in-flight request coalescing.

**Implemented:** Removed observation and the unused force path. Registration still coalesces calls during an in-flight request and checks its successful receipt against the 24-hour interval. A shared helper filters delivered notifications and updates the badge for both read-state and sign-out cleanup.

**Verification:** The focused iOS reaction-notification revision test passes on Xcode 27/iOS 27, and `git diff --check` passes. Live APNs delivery and registration retries were not exercised.

### P2-11 — Remove verified dead Swift functions and types

- [x] Verified unreferenced code includes `consumePendingMeeting`, `decodeMessageDict`, `rebuildThreadMessageIndexes`, `CalendarDateHelpers.isSameDay`, `CalendarFileCache.saveRSVP`, old Auth sign-in helpers, `Box`, and `OutlinedTextFieldStyle`.

**Task prompt:** Remove this exact verified dead-code set one file at a time, retain protocol/delegate callbacks that appear textually single-use, run reference searches after every removal, and build before proceeding to the next file.

**Implemented:** Removed the named dead methods and view types, plus the RSVP writer's now-unused path helper and the unused legacy Auth result/getter they depended on. Kept the live notification router, chat index builder, and Auth sign-out behavior.

**Verification:** Reference searches found no remaining uses of the removed symbols. Xcode 27/iOS 27 simulator app builds passed after each of the seven affected files.

### P2-12 — Remove the redundant chat message-signature pass

- [x] `buildThreadMessageIndex` compares full arrays and separately creates joined string signatures, while its plural mutating wrapper is unused.

**Task prompt:** Remove the dead plural wrapper and replace the duplicate signature pass with one lightweight revision value produced during indexing, preserving render-item invalidation and thread version semantics.

**Implemented:** The unused plural wrapper was removed in P2-11. Index construction now combines each message ID and effective update time into a per-thread revision as it indexes messages. Versions still advance for message identity/time changes, while full array equality still controls render-item rebuilding for other message edits.

**Verification:** The Xcode 27/iOS 27 simulator app build passes. A reference search found no remaining signature helper or plural wrapper, and `git diff --check` passes.

### P2-13 — Remove verified unused view state and parameters

- [x] Verified examples include AddMeeting `linkText/showHelp`, Calendar `screenWidth/calendarScrollPoint/offset`, MeetingInfo screen dimensions, MeetingView overlap flags, CreateClub disclosure flags, ContentView `expanded/scale`, and ChatView `mutedThreads`.

**Task prompt:** Perform a mechanical per-file unused-property cleanup for only the named properties and their call-site parameters, do not redesign state ownership, and stop if a successful Swift build cannot verify a candidate.

**Implemented:** Removed the named unused properties and the four unused MeetingView overlap arguments at their call sites. ChatView had no live `mutedThreads` property; its only occurrences are in stale commented code slated for P2-14. The MeetingInfo geometry state and observer were also removed because they only supplied the unused screen dimensions.

**Verification:** The Xcode 27/iOS 27 simulator app build passes, and `git diff --check` passes.

### P2-14 — Delete stale commented-out implementations

- [x] Large inactive blocks remain in ChatMessagesView, ChatView, AnnouncementViews, ClubInfoView, and TabBarView.

**Task prompt:** Delete stale commented-out implementations while retaining short comments that explain non-obvious current behavior, then run formatting and a focused UI build.

**Implemented:** Removed stale commented-out UI branches, controls, and old message rendering from the five named files. Kept comments that explain live behavior, including the transitional chat deletion observer.

**Verification:** Ran Swift formatting around the edited regions, then passed the Xcode 27/iOS 27 simulator app build and `git diff --check`.

### P2-15 — Remove unused imports

- [x] Notable candidates include DateHandlingFunctions and ContentView imports for Firestore, GoogleSignIn UI, SDWebImage, CUIExpandableButton, and FirebaseDatabaseInternal.

**Task prompt:** Remove unused imports one file at a time, replace internal FirebaseDatabase imports with the public module where required, and typecheck after each file rather than performing a blind bulk rewrite.

**Implemented:** Reduced DateHandlingFunctions to Foundation, removed unused ContentView framework imports, and removed all FirebaseDatabaseInternal imports from the app. ContentView uses the public FirebaseDatabase module; ChatView, FirebaseDataFunctions, and ViewModel already imported it. Removed other unused imports in those same files while keeping modules with referenced symbols.

**Verification:** Xcode 27/iOS 27 simulator builds passed after each of the five files. No FirebaseDatabaseInternal imports remain, and `git diff --check` passes.

### P2-16 — Remove unused RTDB indexes

- [x] `/clubs/name` and `/chats/{id}/messages/time` have no matching current query; current queries use `lastUpdated`, `threadName`, series ID, deletion value, and read-state timestamps.

**Task prompt:** Reverify every RTDB query, remove only the unused `name` and `time` indexes, update configuration tests, and leave every actual query index intact.

**Implemented:** Removed only the unused clubs/name and chat messages/time indexes. The configuration test now asserts the retained indexes for club and message update time, thread name, series ID, deletion value, notification read time, global update time, and retry time, as well as absence of the two unused indexes.

**Verification:** Searched current Swift and backend query ordering, passed all four configuration tests on Node 22, and passed `git diff --check`. No rules were deployed.

### P2-17 — Enforce Node 22 for local and predeploy tests

- [x] `functions/package.json` requests Node 22, but the ordinary local shell can still invoke an older Node executable and fail inside dependencies.

**Task prompt:** Add a small Node-version file and an early test/predeploy major-version assertion with a clear error, document the exact Node 22 command, and do not reinstall dependencies unless necessary.

**Implemented:** Added root `.nvmrc` and a small Node 22 assertion as the `pretest` and `pretest:rules` hooks. Firebase's existing Functions predeploy calls `npm test`, so it runs the same early guard. README now shows the exact Homebrew Node 22 commands for local backend and rules tests.

**Verification:** The Node 22 backend suite passes 98/98 with the pretest hook; the rules pretest hook passes. A simulated Node 20 version exits 1 with a clear message. `git diff --check` passes. No dependencies were reinstalled.

### P2-18 — Fix the TabsCache filename and spelling

- [x] `CachingClasses.swift` writes tab preferences to a filename beginning with a tab character and spells `tabPreferences` incorrectly.

**Task prompt:** Correct the filename and spelling, migrate the tab-prefixed legacy cache once when present, use atomic writes, and preserve existing preferences.

**Implemented:** TabsCache now writes `tab_preferences.json` atomically and uses the corrected `tabPreferences` parameter. On load, it prefers the corrected cache; otherwise it decodes the tab-prefixed legacy file, writes the corrected cache, and removes the legacy file only after the write succeeds.

**Verification:** Two focused Xcode 27/iOS 27 simulator tests pass for migration and corrected-file precedence; `git diff --check` passes.

### P2-19 — Remove the obsolete Personal `fcmToken`

- [x] `Personal.fcmToken` is obsolete under `notificationDevices`, and current rules already deny direct writes to it.

**Task prompt:** Remove `fcmToken` from the Swift model and new profile writes, leave existing Firebase values untouched, and confirm all push delivery uses per-installation registrations.

**Implemented:** Removed the obsolete Swift model property. New profile updates already omit it, and deployed notification registration/delivery reads `notificationDevices/{uid}/{installationID}`. Migration and rollback scripts retain their deliberate references to legacy database values; no live values were touched.

**Verification:** All three focused Xcode 27/iOS 27 profile tests pass, including decoding a legacy profile containing `fcmToken` and confirming it is not re-encoded. Backend notification delivery paths were checked; `git diff --check` passes.

### P2-20 — Consolidate backend identity and role helpers

- [x] `normalizedEmail`, unique-email logic, and `roleValue` have multiple copies, `getRole` is unused, and `resolveEmails` retains a pre-Admin-14 fallback.

**Task prompt:** Consolidate only identity/role primitives into the existing low-level access helper, remove `getRole` and the obsolete Admin fallback after updating test doubles, and avoid abstracting tiny unrelated timestamp helpers.

**Implemented:** `access.js` now owns normalized email, unique email, and role extraction. Calendar, meeting, membership, visibility, and notification services use those primitives. Removed the unused `getRole`, duplicate helpers, and the old per-email Auth fallback; the membership test double now implements Admin 14's `getUsers` batch method.

**Verification:** All 58 focused membership, calendar, meeting, and notification backend tests pass on Node 22. Source search confirms one deployed copy of each helper and no remaining old imports or `getRole`; `git diff --check` passes.

### P2-21 — Centralize super-admin authority safely

- [x] The super-admin email list is repeated many times across rules, backend, and client code, making Dev-to-Official carry-over error-prone.

**Task prompt:** Design and implement a coordinated migration to one authenticated super-admin claim or private authoritative UID registry shared by backend authorization and RTDB rules, include bootstrap/rollback tooling and tests, and do not activate new rules until every intended admin has been provisioned.

**Implemented:** Backend authorization and RTDB rules now require the boolean Firebase Auth claim `phsSuperAdmin`; the iOS client reads that claim for admin controls and no longer contains the admin email list. Added project-scoped Development provisioning manifest, offline plan/bootstrap/verify/rollback tooling with a pre-write backup, and [rollout instructions](SUPER_ADMIN_CLAIM_ROLLOUT.md) requiring all intended admins to be provisioned and verified before deployment. No claims were provisioned and no new rules or Functions were activated.

**Verification:** The full Node 22 backend suite passes 102/102, the local RTDB rules suite passes 11/11, and the full Xcode 27/iOS 27 simulator suite passes 65/65. Tests cover claim-only backend and rule access, denial of a legacy admin email without the claim, pre-write provisioning validation, unexpected claims, backup, and partial rollback. `git diff --check` passes. Live Auth claim propagation and authenticated UI behavior remain to be verified during rollout.

---

## Audit verification baseline

- Codebase-memory graph generation inspected: `2026-09-20T05:54:33Z` with 3,615 nodes and 13,511 edges.
- Relevant graph parse-partial ranges were inspected directly in source.
- Node 22 backend run: 48 tests passed.
- A runtime probe confirmed that `formatMeetingTime` was not exported and global crypto did not provide `createHash` to `meeting-service.js`.
- `git diff --check` passed at the time of the audit.
- The attempted Xcode build did not reach Swift compilation because the selected Xcode installation reported that the iOS 26.2 platform was unavailable.
- This document records an audit baseline; every task must be reverified against the current working tree before editing because source and line numbers can change.
