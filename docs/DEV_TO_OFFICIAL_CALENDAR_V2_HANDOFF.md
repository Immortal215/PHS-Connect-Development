# Calendar v2 Dev-to-Official handoff and legacy retirement record

This record exists so the development rollout can be repeated deliberately in PHS Connect Official without relying on conversational context. It does not authorize a deployment, migration, or edit to the Official repository.

## Final new-version-only decision on 2026-09-19

This decision supersedes the mixed-version compatibility policy described in the historical rollout notes below.

- The calendar-v2 release goes directly to the canonical data model. Previous app versions are unsupported and must be stopped by the existing update-required product gate.
- `/clubs/{clubID}` remains the live public discovery/chat metadata record. Only its superseded `meetingTimes`, `leaders`, `members`, `pendingMemberRequests`, `leadersUIDs`, `membersUIDs`, `calendarStorageVersion`, and `membershipStorageVersion` values are legacy snapshots.
- Those legacy values remain physically stored for audit/recovery, but they are frozen. Updated clients and deployed Functions must not import, repair, project, or treat them as authoritative, and normal membership or meeting activity must not change them.
- The updated app gets its own role from `/userClubMemberships/{uid}`, meeting bodies through authenticated calendar sync, and roster/request details through the authenticated club-access endpoint. The endpoint reads canonical `/clubMemberships` and `/clubJoinRequests`; it never reconstructs data from legacy club arrays.
- The super-admin `clubs/ensure-calendar-v2` runtime endpoint, automatic login/open repair calls, and legacy roster projection writes are removed. Conversion is an operator-run, dry-run-first step before the new client is released.
- The offline migration, visibility backfill, readiness validator, and backup-based rollback scripts remain only until Official has been converted and validated. They are not shipped behavior and never run during ordinary app use.
- Old fields are not deleted during this rollout. Because `/clubs` remains publicly readable for current discovery metadata, an old app may still display a stale snapshot, but that behavior is neither supported nor kept correct; its protected writes remain denied.

Official must not adopt the new-only client until its one-time conversion has completed successfully, the readiness validator passes, and a private pre-conversion export has been retained. Never copy Development Firebase identifiers or data into Official.

## Final Development new-only checkpoint on 2026-09-19

The final new-only implementation and deployment in this section happened only in the Development checkout and Firebase project. No Official source, configuration, or data was changed.

- Confirmed target: Firebase project `user-with-personal-tasks`; RTDB instance `user-with-personal-tasks-default-rtdb`; URL `https://user-with-personal-tasks-default-rtdb.firebaseio.com`; RTDB location `us-central1`.
- A bounded, read-only snapshot of only the ten readiness paths passed the current validator: 42 clubs, 48 canonical meetings, 29 frozen legacy meetings, 184 unresolved identities retained for later account reconciliation, and 71 visibility claims. There were zero missing schemas, markers, roster-identity coverage records, audit records, month-index entries, reciprocal memberships, visibility-claim evidence, or visibility claims. `dataReady` was `true`.
- The temporary bounded snapshot was deleted after validation. No migration, cleanup, club edit, meeting edit, membership edit, or legacy-field deletion was performed during this final checkpoint.
- The backend suite passed 48/48 tests during the Firebase predeploy hook. The unchanged RTDB rules suite had already passed 7/7 emulator tests for this work. Swift parsing, `git diff --check`, and a complete iOS Simulator build with Xcode 27 succeeded.
- All 11 Development Functions were redeployed successfully in `us-central1` on Node 22: `phsApi`, `calendarFeed`, `compactCalendarChangeLog`, `cleanupDeletedClub`, `sendChatNotification`, `sendReactionNotification`, `sendMeetingNotification`, `cleanupStaleNotificationDevices`, `retryNotificationDeliveries`, `auditAuthIdentityLifecycle`, and `cleanupDeletedAccount`.
- This final deployment updated Functions only. It did not deploy RTDB rules or hosting because neither changed in the final new-only removal, and it did not execute a live migration.
- The current deployed runtime no longer has the super-admin repair endpoint, automatic legacy calendar import, or legacy roster projection writes. Existing old values remain stored but frozen. The updated client sanitizes them before caching/display and obtains calendar, roster, request, and role state from canonical authenticated sources.
- The Firebase CLI still reports `firebase-functions` 7.3.2 as not the latest package. This is a warning, not a failed deployment. Do not combine an unplanned Functions SDK upgrade with the Official data cutover; evaluate and test that dependency change separately.

The updated Development app binary still has to be distributed for client-side behavior to change. Previous binaries are intentionally unsupported and must remain behind the update-required gate. Because public `/clubs` metadata remains readable, an old binary may display frozen stale roster/calendar fields; it must not be allowed to perform protected membership or calendar writes.

## Dev deployment evidence on 2026-09-11

The Dev backend, hosting fallback, and write-cutoff RTDB rules were deployed to `user-with-personal-tasks`. The legacy data was retained. The pre-cutover offline dry-run found 42 clubs, 31 meetings, no malformed dates, no canonical conflicts, 184 unresolved identities, and 71 unresolved visibility identities. Its reviewed 811-path atomic plan was applied with triggers disabled. A fresh export then validated all 42 club schemas, all 31 meetings and month indexes, reciprocal memberships, and migration audit evidence with no errors. The export contained no migration-created meeting-notification jobs or legacy single-device FCM tokens. Comparing pre- and post-migration exports found no changes to legacy `meetingTimes`, `leaders`, `members`, or `pendingMemberRequests`.

A migration rerun against the post-cutover export planned zero new meetings, zero malformed dates, zero unresolved visibility work, zero conflicts, and zero legacy tokens to remove. It still projects idempotent membership/unresolved-identity values, so a nonzero candidate update-path count alone is not evidence of duplicated meetings.

A final audit caught that the first migration report retained 71 unresolved meeting-visibility emails only in its local report. Dev corrected this before handoff: the backend and migration now maintain private forward/reverse meeting-visibility claims, reconciliation updates the stable meeting occurrence and publishes a delta without a notification job, and a claims-only 143-path plan retained all 71 Dev records. The final readiness report validates 71 claims, zero missing claims, and zero missing claim evidence. Port `meeting-visibility.js`, the backfill script, its tests, and the strengthened readiness checks to Official; do not rely on an operator retaining the dry-run report as the only reconciliation record.

The first Functions attempt exposed that Node 24 cannot host the Gen1 Firebase Auth deletion trigger. Dev now uses Node 22 for all 11 Functions so Gen1 account cleanup and Gen2 APIs/triggers share one supported runtime. Carry Node 22 to Official unless that trigger is redesigned and reverified.

## Dev Firebase Admin 14 upgrade on 2026-09-13

Development upgraded to `firebase-admin` 14.4.0 while retaining `firebase-functions` 7.3.2 and Node 22. Because Admin 14 removes the legacy root namespace, Dev uses `functions/lib/firebase-admin-services.js` to construct modular Database, Auth, and Messaging services while retaining the existing dependency-injection seam used by business logic and tests. The unused `firebase-functions-test` package was removed instead of forcing its incompatible Admin peer range.

All 11 Development Functions were redeployed in staged groups and verified `ACTIVE` on Node 22. The upgrade passed 50/50 backend tests, 7/7 RTDB rules-emulator tests, all export-load checks, an offline migration rerun, and post-deploy 401/404 API boundary smoke tests. It did not deploy rules, change an RTDB schema, run a live migration, or mutate calendar data. At that point compatibility reads still existed; the final 2026-09-19 new-version-only decision above supersedes that runtime policy without changing the Admin 14 conclusions.

When carrying this upgrade to Official, port the adapter, modular entry-point and script imports, package and lockfile changes, and Admin compatibility tests together. Use Node 22 for install, tests, export loading, migration tooling, and deployment. Do not copy Development Firebase identifiers, credentials, plist values, tokens, or deployment configuration. Verify Official independently, retain the token-based notification path for existing installations, and deploy its Functions in staged groups only after its full backend and rules suites pass. A forced `npm audit fix` is not part of this upgrade; review the remaining transitive advisories separately.

## Dev roster-repair incident on 2026-09-12

The first identity-lifecycle audit removed all 24 resolved Dev memberships after the original rollover. The legacy roster arrays were not lost: all 42 clubs still had leaders, but `/clubMemberships` and `/userClubMemberships` were empty. Two implementation defects caused the apparent data loss:

- Backend eligibility used `email.endsWith("@d214.org")`, which rejects student subdomains such as `@stu.d214.org` and contradicted the existing client behavior that also permits verified Gmail accounts used by Dev and legacy rosters.
- The calendar hydration/cache path replaced the public compatibility roster with only resolved UID entries and persisted empty leader/member arrays into existing device cache files.

Dev corrected the shared identity policy to accept verified enabled `gmail.com`, `d214.org`, and subdomains of `d214.org`; the scheduled audit, reconciliation, membership mutations, calendar subscriptions, visibility resolution, migration, and backfill now use that same rule. A separate `membershipStorageVersion = 2` marker made the temporary super-admin repair independently idempotent for already-converted calendars. The final implementation removes that runtime repair and compatibility-roster behavior after canonical validation; retain this paragraph only as incident evidence.

Functions were redeployed to Development before data repair. A fresh full RTDB backup and reviewed 637-path plan were retained under `.local-rollout-backups/`. The applied plan used disabled triggers, restored 24 active reciprocal memberships plus one pending reverse record, cleared 25 stale unresolved duplicates, and left 184 identities unresolved until matching verified accounts exist. Post-write validation passed all 42 schemas, 31 canonical meetings, 71 visibility claims, reciprocal roles, roster coverage, and audit markers. A structural comparison proved the canonical meeting tree and all legacy `meetingTimes`, `leaders`, `members`, and `pendingMemberRequests` values were unchanged. The user had independently customized RTDB rules; this repair deployed Functions only and did not overwrite those rules.

## Dev super-admin access correction on 2026-09-12

The initial v2 client treated super-admins as leaders in the club UI, but `CalendarDataStore` followed only `/userClubMemberships/{uid}`. A super-admin who was not a member of a club therefore had no canonical meeting cursor or meeting bodies to edit. Club editing could also begin from a stale public-club cache, and the RSVP attendance endpoint checked only the stored membership role.

Dev corrected this without inventing admin memberships or another database tree. A signed-in super-admin now observes only `/clubCalendars/{clubID}/latestChange` for each existing club and uses the authenticated delta-sync endpoint with leader-equivalent read access. Matching cursors download no meeting bodies. The backend permits the same configured super-admin policy for calendar sync, meeting mutations, and leader attendance-list reads. Actual membership remains authoritative for subscriptions and personal RSVP eligibility, so a nonmember super-admin cannot subscribe or RSVP merely because they can administer the club.

Opening the club editor performs one bounded `/clubs/{clubID}` metadata refresh and awaits a canonical authenticated roster refresh before presenting the form, unless a pending local edit already exists. It never invokes legacy repair. Healthy editor opens do not create a calendar lock.

The Development RTDB rules and `phsApi` Function were deployed after this correction to `user-with-personal-tasks`; the verified deployed Function was active in `us-central1` on Node 22 with source hash `cb3b24b8f185562e6f3d3bae1d6895013c227d66`. Local verification passed 44 backend tests, 7 rules-emulator tests, Swift parsing, and an iOS Simulator build. No simulator was already booted, so the signed-in super-admin UI flow was not visually exercised. No migration or live data mutation was performed as part of this correction.

## Dev public-club cache correction on 2026-09-12

The old cache startup path bounded only its `childAdded` query. It also attached unbounded `childChanged` and `childRemoved` observers to `/clubs`, so Firebase still initialized and maintained the complete public club collection. A damaged cache with an empty leader list also forced the whole collection to reload.

Dev now loads valid `ClubCache` files first and attaches both add/change observers to one `lastUpdated` query strictly newer than the newest cached value. Missing, corrupt, or previously sanitized cache files are fetched individually. Cache files are written atomically, and their IDs are recorded only after the file write succeeds. The shallow ID comparison waits for Firebase's initial query-value boundary, after its initial child-added events, so a clean install does not request the same club bodies through both synchronization paths.

Deletion reconciliation intentionally does not add a tombstone tree or per-delete backend write. On initial appearance, reconnect, and foreground activation, the client performs one public RTDB REST `shallow=true` request for `/clubs`, compares only the returned club IDs, deletes stale local files, and fetches only IDs missing from the local cache. This also recovers a legacy club that lacks `lastUpdated` without downloading every club body. Deletion is therefore reconciled at those lifecycle boundaries rather than instantly while an app remains continuously foregrounded. Port this exact tradeoff to Official unless product requirements change.

This correction is client-only. It needs no Functions, rules, or data deployment and creates no Firebase writes. Local verification passed Swift parsing, the 44 backend tests, the 7 rules-emulator tests, and an iOS Simulator build.

## Dev no-op identity-lock correction on 2026-09-12

`CalendarDataStore` intentionally invokes the authenticated identity-reconciliation endpoint once when it initializes an account cache. The first backend implementation acquired `/internal/calendarLocks/{clubID}` for every current membership and visibility claim before determining whether anything required repair. Consequently, a settled login briefly created and deleted calendar locks even though no user data changed.

Dev now derives the affected club set from mismatched membership identity, role-transfer claims, and visibility claims whose `lastUID` still needs reconciliation. If that set is empty, the endpoint returns before any transaction or database update. Settled visibility claims are no longer rewritten merely to refresh `updatedAt`. Locks remain mandatory for genuine reconciliation so concurrent membership and calendar mutations cannot overwrite each other. The regression test asserts zero transactions and zero writes for a settled identity. After the subsequent read-state-pruning tests, the full backend suite passes 47/47, and `phsApi` was deployed successfully to Development. Port the backend change and regression test to Official.

Notification read state is one record per user and logical scope (`chatID + threadName`, or `meetingID`), retaining only the latest seen message ID or meeting revision and pruning beyond 500 scopes. Dev avoids the former collection-wide pruning query on ordinary revision advances; it now runs only when a transaction creates a new logical scope. Port both regression tests so Official does not reintroduce a read of up to 525 state records for every message viewed.

## Current release policy

- Canonical `/clubMeetings`, `/clubCalendars`, membership indexes, RSVP, subscriptions, and notification structures are authoritative.
- Previous app versions are unsupported. The release retains the update-required gate and does not maintain legacy projections for them.
- Legacy `meetingTimes`, `leaders`, `members`, `pendingMemberRequests`, UID arrays, and storage markers remain frozen snapshots. They are never refreshed by canonical additions, edits, visibility changes, cancellations, joins, leaves, approvals, rejections, or leader changes.
- Ordinary public club/discovery/chat metadata under `/clubs` remains live because it is part of the permanent model, not a compatibility projection.
- Calendar and membership writes require the updated app/backend. There is no bidirectional synchronization, runtime legacy import, or repair trigger.
- RTDB root write access remains denied. Configured super-admins receive leader-equivalent access on the specific public club/chat fields still written directly by the app, while full club saves, rosters, meetings, RSVP, subscriptions, and notification data continue through authenticated backend operations. Do not replace these scoped grants with `/clubs/{clubID}` or database-root write access: an ancestor grant would bypass the frozen legacy meeting/roster protections.

## Historical super-admin repair design — do not port as runtime behavior

The following explains the temporary Development recovery path that existed during conversion. It is retained as incident history only. The final new-version-only implementation removes this endpoint and all automatic client calls. Official must use the offline migration and validator before release instead.

The temporary Swift client used an in-memory `calendarRepairRequests` set to avoid duplicate calls in one app session. The temporary backend provided the durable guarantee:

1. It accepts the repair only from a configured super-admin email.
2. It acquires `/internal/calendarLocks/{clubID}` so only one conversion for that club can run at a time.
3. It checks `/clubCalendars/{clubID}/schemaVersion` separately from `/clubs/{clubID}/membershipStorageVersion`. A calendar schema value of `2` prevents any legacy meeting reimport; a membership marker below `2` permits a one-time roster-index repair without touching canonical meetings.
4. The first conversion writes canonical meeting bodies, indexes, cursor, `schemaVersion = 2`, `/clubs/{clubID}/calendarStorageVersion = 2`, and `/internal/legacyCalendarRepairs/{clubID}` in one root RTDB update.
5. The audit record includes the legacy source hash, imported count, unresolved visibility identities, actor UID, and repair time.
6. A retry after a committed request whose HTTP response was lost sees both version markers and returns `existing`. A simultaneous request either waits behind the per-club lock behavior or receives a retryable conflict; it cannot perform a second conversion or roster repair.
7. A detected partial canonical conversion is rejected for explicit reconciliation instead of overwriting records.

`schemaVersion` and private migration checkpoints remain conversion evidence. The updated app does not inspect public storage-version markers or trigger repairs.

## Verified local target differences as of 2026-09-11

| Checkout | Firebase project in local files | RTDB URL in plist | Bundle ID |
| --- | --- | --- | --- |
| PHS-Connect-Development | `user-with-personal-tasks` | `https://user-with-personal-tasks-default-rtdb.firebaseio.com` | `Official.PHS.Dev` |
| PHS-Connect-Official | `phs-connect` | `https://phs-connect-default-rtdb.firebaseio.com` | `PHS.PHS-Connect-Official` |

The Official checkout currently has substantial uncommitted source/project changes. Preserve and reconcile those changes; do not copy whole Dev files over them. Its inspected `firebase.json` currently declares Functions only, while Dev adds database and hosting configuration. Verify the actual Official RTDB instance/location, Functions region, billing, hosting site, entitlements, deployed functions, and APNs environment before changing configuration. Local filenames do not prove live deployment state.

## Carrying the implementation into Official

1. Start from a committed Official worktree and record `git status`. Preserve all unrelated changes.
2. Re-run code-graph discovery and coverage against Official. Its source directory capitalization differs (`User with Tasks` versus Dev's `User With Tasks`), and UI files have diverged.
3. Port behavior and tests, not Firebase identifiers. Never copy Dev's `.firebaserc`, `GoogleService-Info.plist`, bundle identifier, database URL, hosting domain, APNs environment, or cached subscription tokens.
4. Port the backend modules, rules, hosting fallback, one-time migration/backup/readiness scripts, and Swift integration by adapting each call site to Official's current source. Do not port the removed runtime repair endpoint, automatic repair calls, or legacy roster projections.
   Preserve the separate super-admin calendar-access path: do not write synthetic `/clubMemberships` or `/userClubMemberships` records for administrators. Port the scoped `latestChange` rule, administrative cursor listeners, authenticated admin delta sync, bounded editor refresh, and admin attendance-list authorization together.
5. Confirm Official uses Node 22, `firebase-admin` 14.4.0, and a compatible Firebase Functions version. Port the modular Admin-services adapter and its compatibility tests; do not restore the removed legacy namespace or force the incompatible `firebase-functions-test` peer range. Node 22 is required by Admin 14 and while the account-deletion handler remains a Gen1 Firebase Auth trigger. Then run backend tests, rules-emulator tests, and iPhone/iPad builds.
6. Run `validate-calendar-v2-readiness.js` and the migration in dry-run mode against the exact Official project/instance. Resolve malformed dates, canonical conflicts, reciprocal-role errors, and unresolved identities explicitly.
7. Follow `CALENDAR_V2_ROLLOUT.md`: backup, deploy the new-only backend, deny legacy calendar/membership writes through rules, apply the reviewed migration, validate, and only then release the update-required client. Do not deploy from the Dev target.

Read-only validation command after credentials and the target are verified:

```sh
cd /path/to/PHS-Connect-Official/functions
node scripts/validate-calendar-v2-readiness.js \
  --project phs-connect \
  --database-url https://phs-connect-default-rtdb.firebaseio.com
```

## Frozen snapshot retention

This rollout does not delete or refresh the superseded fields. `/clubs` remains readable because its ordinary discovery/chat metadata is still part of the current architecture. Updated clients sanitize the superseded properties before caching or displaying a club and hydrate roster/request state only from canonical authenticated responses.

If a later project decides to delete the frozen fields, treat that as a separate destructive cleanup: export a fresh backup, verify canonical parity again, use a reviewed dry-run cleanup plan, and delete only the named superseded children. Never delete ordinary club metadata, canonical meetings, unresolved identity records, migration evidence, RSVP history, subscription tokens, notification registrations, or read state.

## Evidence to retain from each environment

Keep the dry-run JSON, encrypted backups, migration output, readiness-validator output, test logs, app build results, rules-emulator results, malformed/unresolved reconciliation log, deployment command output, exact Git commit, Firebase project/instance IDs, function region, hosting site, and rollout timestamp. Never store raw subscription tokens or FCM tokens in these reports.
