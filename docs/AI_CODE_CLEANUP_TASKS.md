# PHS Connect AI Implementation Tasks

**Current execution boundary:** Complete P1 in priority order, obeying the required model switches, then stop. Do not begin P2 (user instruction, 2026-09-21).

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

- [ ] `CalendarMeetingIndex.swift` assigns every event only to its first day and repeatedly creates/parses dates during sorting.

**Task prompt:** Expand timed and all-day meetings across each overlapping Chicago calendar day with exclusive all-day ends, deduplicate occurrences, use a shared cached date-only formatter, and test overnight, multiday, DST, and month-boundary events.

### P1-05 — Stop rereading the full calendar cache after each mutation

- [ ] `applySnapshot`, `applyDelta`, and `removeClub` in `CalendarDataStore.swift` call `load()` after mutations, rereading all account calendar files.

**Task prompt:** Keep the actor's current snapshot in memory, apply targeted mutations, stage snapshot replacements before swapping them atomically, commit cursors only after durable writes, evict stopped-session cache actors, and remove or consume the unused `repairedClubIDs` result.

### P1-06 — Prevent stale sync tasks from committing

- [ ] `scheduleSync` in `CalendarDataStore.swift:613` cannot stop a superseded same-account task after it begins a cache-actor mutation.

**Task prompt:** Assign a per-session/per-club sync generation and have the cache actor validate it immediately before file and manifest commits so stale requests cannot overwrite newer results.

### P1-07 — Filter calendar changes before reading bodies

- [ ] `syncClubCalendar` in `meeting-service.js:602` performs sequential meeting-body reads that are unnecessary for tombstones and out-of-range changes.

**Task prompt:** Filter change records by operation and date-range metadata first, emit tombstones without body reads, fetch only required upsert bodies with bounded concurrency, and prove unchanged/deleted/out-of-range deltas read zero bodies.

### P1-08 — Stop the next-meeting preview after the first valid result

- [ ] `nextPublicMeeting` in `meeting-service.js:591` loads the full one-year candidate range and all bodies before selecting one unrestricted meeting.

**Task prompt:** Walk month indexes chronologically, fetch candidates in start order, stop after the earliest valid unrestricted meeting is known, preserve overlap handling, and measure meeting-body reads.

### P1-09 — Reuse meeting visibility and membership work

- [ ] `saveMeetings` repeatedly resolves identical visibility emails and revalidates RSVP access for every occurrence even when access did not change.

**Task prompt:** Resolve unique visibility emails once per request, reuse a bounded membership snapshot, run RSVP revalidation only when club/visibility/cancellation changes, and preserve per-occurrence IDs and responses.

### P1-10 — Use acknowledgment responses instead of another full read-state fetch

- [ ] `NotificationRegistrationManager.acknowledge` ignores the returned state and immediately requests the complete read-state collection, while background sync pushes also ignore the state included in their payload.

**Task prompt:** Return and decode the saved state key/type/revision, merge it monotonically into local state, remove only matching delivered notifications without another GET, retain full reconciliation for foreground activation, and move registration lookup after a committed backend transaction.

### P1-11 — Avoid pruning notification state on every new scope

- [ ] `pruneReadState` in `notifications.js:297` queries up to 525 records whenever a new thread or meeting read scope is created.

**Task prompt:** Add a simple low-write prune cadence or threshold hint so new scopes do not run the 525-record query every time, keep the hard bound, and test monotonic state and concurrent acknowledgments.

### P1-12 — Reduce feed-token and cache-retention reads

- [ ] `resolveToken` reads several subscription scalars, and feed cache cleanup reads the entire cache parent including calendar bodies.

**Task prompt:** Make the atomically maintained token record authoritative for generation/revocation where safe, continue validating Auth/access before cache or 304 responses, and remove deterministic expired day keys without downloading cached feed bodies.

### P1-13 — Stop cold chat loads from downloading complete histories

- [ ] `fetchChatsMetaData` in `FirebaseDataFunctions.swift:611` downloads whole chats, while `loadChats` in `ChatView.swift:2034` has duplicate loops and nested queue/MainActor/task transitions.

**Task prompt:** Fetch only scalar chat metadata plus a bounded recent-message page, page older history on demand, deduplicate chat IDs with a Set, flatten the concurrency flow, and preserve existing chat UI and ordering.

### P1-14 — Remove the unused `lastMessage` copy

- [ ] `sendMessage` reads the complete chat and maintains `/lastMessage`, but the current app and Functions backend do not consume that node for behavior.

**Task prompt:** Reverify current consumers, then remove the unused `Chat.lastMessage` property, read/write maintenance, and rules while leaving existing Firebase values untouched; ensure chat ordering continues using loaded messages.

### P1-15 — Delete threads through the indexed query and emit deletion records

- [ ] `removeThread` in `FirebaseDataFunctions.swift:834` scans all messages, deletes matching children without `deletedMessages` entries, and can leave pinned/sidebar state inconsistent.

**Task prompt:** Use the existing indexed `threadName` query, atomically delete returned messages while writing `deletedMessages` records and fixing pinned state, and test offline clients plus deletion of the newest thread message.

### P1-16 — Scope private chat caches by project and account

- [ ] `ChatCache` and deletion cursors live in Documents without Firebase project or UID scoping, while several chat indices use separator-encoded AppStorage strings.

**Task prompt:** Move private chat files and cursors to Application Support v2 scoped by project and UID, use atomic writes and Codable sets/dictionaries, migrate or safely discard old cache files, and clear private memory/listeners on account change.

### P1-17 — Remove unused chat fields and the typing listener

- [ ] `Chat` contains unused `directMessageTo`, `typingUsers`, `edited`, and `mentions` fields, and each active chat observes `typingUsers` despite having no writer or UI consumer.

**Task prompt:** Verify current graph and textual references, remove unused model fields/parameters and the typing observer/rule, leave stored legacy values untouched, and preserve the notification-mode enum without adding mention behavior.

### P1-18 — Make reaction mutation concurrency-safe

- [ ] `updateMessageReaction` replaces an entire emoji user-ID array and can lose simultaneous reactions from separate devices.

**Task prompt:** Preserve the current reaction schema and UI while using a transaction on the emoji's user-ID array, or migrate to a UID-keyed map only if demonstrably simpler, and test simultaneous add/remove operations.

### P1-19 — Update only missing profile fields during user initialization

- [ ] `createUserNodeIfNeeded` reads `/users/{uid}` and can rewrite default favorites while filling a missing profile field.

**Task prompt:** Read only required profile scalars and update only missing owned fields, never rewrite favorites/preferences or legacy `fcmToken`, and test partial existing profiles.

### P1-20 — Resolve announcement club names locally

- [ ] `AnnouncementViews.swift` already receives the club collection but performs separate Firebase reads for missing club names.

**Task prompt:** Resolve club names from the supplied club collection, remove `getClubNameByID` if no callers remain, and retain the existing unknown-club fallback.

### P1-21 — Use transactions for shared arrays

- [ ] Favorites, announcement `peopleSeen`, and club `chatIDs` are downloaded, modified locally, and replaced, allowing concurrent-device updates to be lost.

**Task prompt:** Convert favorites, `peopleSeen`, and `chatIDs` mutations to focused RTDB transactions while preserving their current stored shape and UI behavior, and test concurrent devices.

### P1-22 — Fetch leader RSVP profile names concurrently

- [ ] `listRSVPs` in `meeting-service.js:709` performs one awaited user-name read after another.

**Task prompt:** Fetch only required profile names with bounded parallelism, keep response ordering deterministic, and test inactive historical responses and missing profiles.

### P1-23 — Expire completed operation and notification records

- [ ] Completed `meetingOperations` and `meetingNotificationJobs` records are retained indefinitely.

**Task prompt:** Define a retry-safe retention window, add expiration indexes and scheduled bounded cleanup, retain completed idempotency receipts long enough for retries, and test that cleanup never causes duplicate committed meetings.

### P1-24 — Simplify and correctly debounce Search filtering

- [ ] `calculateFiltered` in `SearchClubView.swift:802` duplicates branches, chains multiple sorts, mutates loading state, and is called by multiple one-second timers and duplicate appearances.

**Task prompt:** Create one pure filter-and-priority comparator, replace repeated timers with one cancellable task-based debounce for text input only, remove duplicate lifecycle calls, and preserve favorites/leaders/members/name ordering.

### P1-25 — Share one correct leader/member email parser

- [ ] `addLeaderFunc` in `CreateClubView.swift:1024` has five delimiter branches, validates only the combined input, and incorrectly treats hyphens as separators.

**Task prompt:** Extract one small shared email parser used by leader and member editors, validate every normalized address independently, preserve Gmail and D214 acceptance plus the six-leader limit, and test display-name input and hyphenated addresses.

### P1-26 — Remove development-specific backend URL fallbacks

- [ ] `subscription-service.js` and `constants.js` embed Dev-specific project and hosting identifiers that could be carried accidentally into Official.

**Task prompt:** Derive project-specific URLs from verified runtime configuration, fail closed when required deployment metadata is absent, retain explicit emulator/test overrides, and prevent Dev identifiers from carrying into Official.

---

## P2 — Lower-risk simplification and dead-code removal

### P2-01 — Remove the unused authenticated meetings-list route

- [ ] `GET /meetings` and `listMeetings` duplicate the active delta-sync path and have no current app, test, script, or hosting caller.

**Task prompt:** Reverify all callers, then remove the unused `/meetings` route/import/export and `listMeetings` implementation while retaining `/calendar/sync` and next-public-meeting behavior.

### P2-02 — Move migration-only calendar code out of the deployed library

- [ ] `functions/lib/legacy-calendar.js` is used by migration scripts and tests rather than deployed runtime handlers.

**Task prompt:** Move strict legacy conversion helpers beneath `functions/scripts/lib`, update migration and tests, ensure production imports do not reference them, and retain all one-time tooling for the Official-project handoff.

### P2-03 — Replace duplicated AddMeeting model construction

- [ ] `addInfoToMeetingChild` and `addInfoToHelper` duplicate meeting field assignment, while preview rendering follows parallel branches.

**Task prompt:** Replace the two mutation helpers with one pure meeting builder used by preview and save, render the preview once, and preserve occurrence/series IDs and all-day semantics.

### P2-04 — Share the Markdown-editing helper

- [ ] `AddMeetingView` and `AnnouncementViews` contain effectively identical Markdown style and link mutation functions.

**Task prompt:** Extract one small inout String/NSRange Markdown helper without creating a framework, retain existing alerts and selection clearing, and use it from both views.

### P2-05 — Share Firebase boolean normalization

- [ ] `ChatView` and `Settings` contain identical 29-line `boolFromGlobalSetting` implementations.

**Task prompt:** Move Firebase boolean normalization to one short shared helper, cover Bool/NSNumber/Int/string/null values, and replace both copies.

### P2-06 — Simplify PHSAPIClient generics

- [ ] `PHSAPIClient.request` has an unused `response:` argument, an existential `AnyEncodable` wrapper, and a forced generic cast for empty responses.

**Task prompt:** Simplify the request API with safe generic body/response overloads or a dedicated no-content method, remove the unused argument and force cast, and update callers without changing authentication or error behavior.

### P2-07 — Trim unused client DTO fields

- [ ] The client decodes membership timestamps/hashes, request timestamps, `ownMembership`, several subscription timestamps, RSVP timestamps, and expanded notification-state metadata that it never consumes.

**Task prompt:** Trim only graph- and source-verified unused client DTO fields, rely on Decodable ignoring additional server fields, keep server authorization/audit metadata intact, and add decoding fixtures to prove compatibility.

### P2-08 — Consolidate membership action wrappers

- [ ] Join, leave, request, and cancellation wrappers repeat the same API/toast flow and accept email arguments they ignore.

**Task prompt:** Remove the ignored email parameters and route these actions through one private membership-action helper while preserving every public wrapper's exact success/error copy and callers.

### P2-09 — Remove dead club-edit recovery state

- [ ] `ClubEditUndoStore` never assigns `recoveredClub`, contains an empty `needsRecovery` branch, and persists an unused `submittedAt` value.

**Task prompt:** Remove only the dead recovery field, empty branch, unused timestamp, and corresponding `ClubInfoView` observer while preserving the persisted operation ID, retry scheduling, undo window, and photo cleanup.

### P2-10 — Simplify NotificationRegistrationManager state

- [ ] `NotificationRegistrationManager` is never observed and every synchronization call uses the default `force: false`, leaving unused observation and force machinery.

**Task prompt:** Remove unnecessary `@Observable`, the unused force parameter/state, and duplicate delivered-notification filtering through one small helper while retaining the 24-hour throttle and in-flight request coalescing.

### P2-11 — Remove verified dead Swift functions and types

- [ ] Verified unreferenced code includes `consumePendingMeeting`, `decodeMessageDict`, `rebuildThreadMessageIndexes`, `CalendarDateHelpers.isSameDay`, `CalendarFileCache.saveRSVP`, old Auth sign-in helpers, `Box`, and `OutlinedTextFieldStyle`.

**Task prompt:** Remove this exact verified dead-code set one file at a time, retain protocol/delegate callbacks that appear textually single-use, run reference searches after every removal, and build before proceeding to the next file.

### P2-12 — Remove the redundant chat message-signature pass

- [ ] `buildThreadMessageIndex` compares full arrays and separately creates joined string signatures, while its plural mutating wrapper is unused.

**Task prompt:** Remove the dead plural wrapper and replace the duplicate signature pass with one lightweight revision value produced during indexing, preserving render-item invalidation and thread version semantics.

### P2-13 — Remove verified unused view state and parameters

- [ ] Verified examples include AddMeeting `linkText/showHelp`, Calendar `screenWidth/calendarScrollPoint/offset`, MeetingInfo screen dimensions, MeetingView overlap flags, CreateClub disclosure flags, ContentView `expanded/scale`, and ChatView `mutedThreads`.

**Task prompt:** Perform a mechanical per-file unused-property cleanup for only the named properties and their call-site parameters, do not redesign state ownership, and stop if a successful Swift build cannot verify a candidate.

### P2-14 — Delete stale commented-out implementations

- [ ] Large inactive blocks remain in ChatMessagesView, ChatView, AnnouncementViews, ClubInfoView, and TabBarView.

**Task prompt:** Delete stale commented-out implementations while retaining short comments that explain non-obvious current behavior, then run formatting and a focused UI build.

### P2-15 — Remove unused imports

- [ ] Notable candidates include DateHandlingFunctions and ContentView imports for Firestore, GoogleSignIn UI, SDWebImage, CUIExpandableButton, and FirebaseDatabaseInternal.

**Task prompt:** Remove unused imports one file at a time, replace internal FirebaseDatabase imports with the public module where required, and typecheck after each file rather than performing a blind bulk rewrite.

### P2-16 — Remove unused RTDB indexes

- [ ] `/clubs/name` and `/chats/{id}/messages/time` have no matching current query; current queries use `lastUpdated`, `threadName`, series ID, deletion value, and read-state timestamps.

**Task prompt:** Reverify every RTDB query, remove only the unused `name` and `time` indexes, update configuration tests, and leave every actual query index intact.

### P2-17 — Enforce Node 22 for local and predeploy tests

- [ ] `functions/package.json` requests Node 22, but the ordinary local shell can still invoke an older Node executable and fail inside dependencies.

**Task prompt:** Add a small Node-version file and an early test/predeploy major-version assertion with a clear error, document the exact Node 22 command, and do not reinstall dependencies unless necessary.

### P2-18 — Fix the TabsCache filename and spelling

- [ ] `CachingClasses.swift` writes tab preferences to a filename beginning with a tab character and spells `tabPreferences` incorrectly.

**Task prompt:** Correct the filename and spelling, migrate the tab-prefixed legacy cache once when present, use atomic writes, and preserve existing preferences.

### P2-19 — Remove the obsolete Personal `fcmToken`

- [ ] `Personal.fcmToken` is obsolete under `notificationDevices`, and current rules already deny direct writes to it.

**Task prompt:** Remove `fcmToken` from the Swift model and new profile writes, leave existing Firebase values untouched, and confirm all push delivery uses per-installation registrations.

### P2-20 — Consolidate backend identity and role helpers

- [ ] `normalizedEmail`, unique-email logic, and `roleValue` have multiple copies, `getRole` is unused, and `resolveEmails` retains a pre-Admin-14 fallback.

**Task prompt:** Consolidate only identity/role primitives into the existing low-level access helper, remove `getRole` and the obsolete Admin fallback after updating test doubles, and avoid abstracting tiny unrelated timestamp helpers.

### P2-21 — Centralize super-admin authority safely

- [ ] The super-admin email list is repeated many times across rules, backend, and client code, making Dev-to-Official carry-over error-prone.

**Task prompt:** Design and implement a coordinated migration to one authenticated super-admin claim or private authoritative UID registry shared by backend authorization and RTDB rules, include bootstrap/rollback tooling and tests, and do not activate new rules until every intended admin has been provisioned.

---

## Audit verification baseline

- Codebase-memory graph generation inspected: `2026-09-20T05:54:33Z` with 3,615 nodes and 13,511 edges.
- Relevant graph parse-partial ranges were inspected directly in source.
- Node 22 backend run: 48 tests passed.
- A runtime probe confirmed that `formatMeetingTime` was not exported and global crypto did not provide `createHash` to `meeting-service.js`.
- `git diff --check` passed at the time of the audit.
- The attempted Xcode build did not reach Swift compilation because the selected Xcode installation reported that the iOS 26.2 platform was unavailable.
- This document records an audit baseline; every task must be reverified against the current working tree before editing because source and line numbers can change.
