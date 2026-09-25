# Calendar v2, RSVP, cache, and notification rollout

This document is the deployment runbook and rollout record. Migration tooling remains dry-run by default.

## Final rollout boundary on 2026-09-19

The release is new-version-only. The app and deployed backend use canonical v2 structures exclusively and do not contain automatic legacy import, repair, or roster-projection behavior. Previous versions are unsupported, so release requires a verified update-required mechanism; this source checkout alone does not prove an external minimum-version gate is active. Superseded Firebase fields are retained as frozen audit snapshots rather than deleted; ordinary public discovery/chat metadata under `/clubs` remains live. The offline scripts exist only to convert and validate Official before its release.

## Dev rollout state on 2026-09-11

- Verified live target: Firebase project `user-with-personal-tasks`, RTDB instance `user-with-personal-tasks-default-rtdb`, Functions region `us-central1`, and hosting site `user-with-personal-tasks`.
- A full RTDB export and Firebase Auth export were created under the ignored, permission-restricted `.local-rollout-backups/` directory. They contain private data and must not be committed.
- The offline dry-run examined 42 clubs and 31 legacy meetings. It reported zero malformed dates, zero conflicts, 184 unresolved identities, and 71 unresolved meeting-visibility identities. Unresolved entries must remain private and receive no access until reconciled.
- Eleven backend Functions and hosting were deployed successfully on Node 22. Unauthenticated `phsApi` access returned 401, an invalid calendar token returned 404, and the meeting fallback returned 200 without private meeting content.
- `database.rules.json` was deployed successfully. Legacy `/clubs/{clubID}/meetingTimes` and roster/request writes are now blocked while the existing values remain readable and stored.
- The validated 811-path offline plan was applied as one root RTDB update with triggers disabled. The post-migration export validates 42/42 club schemas, 31 canonical meetings, complete month indexes, reciprocal membership roles, and all migration audit checkpoints. It contains no migration-created meeting-notification jobs and no legacy single-device FCM tokens.
- A protected-field comparison against the pre-cutover export found zero changes to legacy `meetingTimes`, `leaders`, `members`, or `pendingMemberRequests`. A post-migration rerun found zero new meetings, malformed dates, visibility work, conflicts, or legacy tokens to remove.
- A final visibility-reconciliation audit found 71 unresolved legacy meeting-visibility emails. A claims-only, 143-path atomic update retained all 71 in private forward/reverse indexes without rewriting meetings, clubs, memberships, calendars, or notification jobs. The readiness validator now verifies those mappings and their completion evidence.
- After the 2026-09-12 cache, no-op identity-reconciliation, and read-state-pruning corrections, the then-current Functions suite passed 47/47 tests, the RTDB rules emulator passed 7/7 tests with the installed Java runtime, Swift parsing passed, and the iOS Simulator build succeeded. The signed-in iPhone/iPad visual pass, real two-device notification behavior, and external Apple/Google subscription refresh behavior remained unverified.
- `phsApi` was redeployed successfully to Development after the no-op identity-reconciliation correction. An already-settled app launch now reads the compact identity inputs but performs no calendar-lock transaction and no database update; real membership, visibility, meeting, deletion, and migration mutations still use locks.
- Read state remains one bounded record per chat thread or meeting rather than one record per notification. The pruning query now runs only when a transaction creates a new scope; advancing the latest seen message or meeting revision in an existing scope does not reread the user's read-state collection. `phsApi` was redeployed successfully to Development after this correction.

## Final Development new-only checkpoint on 2026-09-19

- The bounded live-readiness snapshot passed for 42 clubs, 48 canonical meetings, 29 frozen legacy meetings, 184 privately retained unresolved identities, and 71 visibility claims. All schema, migration-evidence, roster-coverage, month-index, reciprocal-membership, and visibility-claim error lists were empty, so `dataReady` was `true`.
- The final Functions predeploy suite passed 48/48 tests, and the unchanged RTDB rules suite remains at 7/7 passing emulator tests. Swift parsing and `git diff --check` passed, and a complete iOS Simulator build succeeded.
- All 11 Development Functions were redeployed successfully to `user-with-personal-tasks` in `us-central1` on Node 22. This final deployment changed Functions only; it did not deploy rules or hosting, execute a migration, delete legacy fields, or mutate club/calendar/membership data.
- A live rules read confirmed the deployed Development rules match `database.rules.json`: database-root writes are denied, canonical private trees are client-write-denied, and frozen legacy meeting/roster/request children remain read-only.
- Signed-in iPhone/iPad behavior, real two-device notification reconciliation, and external Apple/Google subscription refresh behavior still require release-device verification.

## Firebase Admin 14 upgrade on 2026-09-13

- Development now uses `firebase-admin` 14.4.0, `firebase-functions` 7.3.2, and the existing Node 22 runtime. A small modular Admin-services adapter replaces the removed legacy Admin namespace while preserving the backend modules' established injected-service interface.
- The unused `firebase-functions-test` dependency was removed because its published peer range does not support Admin 14. No peer-dependency override is used.
- All 11 Development Functions were redeployed in staged groups and subsequently reported `ACTIVE` on Node 22. The authenticated API returned 401 without a credential, and the calendar feed returned 404 for an invalid token after deployment.
- Verification passed 50/50 backend tests, 7/7 RTDB rules-emulator tests, all 11 export-load checks, and the offline migration rerun. The offline readiness check correctly remained blocked for an older pre-repair export; no live migration or RTDB data mutation was performed for this SDK upgrade.
- For that dependency-only upgrade, compatibility was intentionally retained at the time: there were no Swift, RTDB schema, RTDB-rule, endpoint, notification-payload, or calendar-feed format changes. The later final new-version-only decision above supersedes the legacy-runtime policy without changing the Admin 14 result. Existing registration-token-based FCM delivery remains supported even though Firebase now recommends Firebase Installation IDs for some token-management workflows.
- Production dependency audit findings decreased from 17 to 6 after the locked install. The remaining findings are transitive (`brace-expansion`, `gaxios`/`uuid`, `jws`, `minimatch`, and `websocket-driver`) and require a separately reviewed dependency update; do not use a forced audit fix during rollout.

## Permanent data ownership

- `/clubs/{clubID}` remains the live public discovery/chat metadata record. Superseded `meetingTimes`, `leaders`, `members`, `pendingMemberRequests`, UID arrays, and storage markers remain stored as frozen snapshots; updated clients sanitize them and deployed Functions never project or repair them. Previous app versions are unsupported.
- `/clubMemberships/{clubID}/{uid}` and `/userClubMemberships/{uid}/{clubID}` are the reciprocal UID-authoritative access indexes.
- `/clubJoinRequests/{clubID}/{uid}` stores pending requests; pending entries do not grant calendar or RSVP access.
- `/clubMeetings/{clubID}/{meetingID}` stores stable occurrences. `/clubCalendars/{clubID}` stores small month indexes and a bounded delta log, not public meeting bodies.
- `/meetingRSVPs/{meetingID}/{uid}` stores a response independently of meetings. `/userRSVPIndex/{uid}/{meetingID}` is a private bounded lookup used to inactivate retained responses after access loss.
- `/calendarSubscriptions` and `/calendarTokens` store private token state and lazy feed caches. Raw tokens remain client-side in account/project-scoped Keychain; the database stores only hashes.
- `/notificationDevices`, `/notificationReadState`, and private `/internal` indexes/jobs support multiple installations, monotonic acknowledgement, retry safety, cleanup, migration, and identity reconciliation. `/internal/meetingVisibilityClaims` and its meeting-to-hash reverse index retain unresolved targeted-visibility emails and allow the authenticated backend to restore access when the verified school account appears; intentional visibility removal revokes the claim.

The iOS cache is scoped to `Application Support/PHSConnectCache/v2/{projectID}/{uid}`. It commits meeting files before advancing cursors, removes inaccessible clubs on membership loss, rejects responses from an old account-session generation, and rehydrates damaged or compacted state through bounded backend queries.

## Preflight: verify the real target

Do not infer safety from the repository name. The checked-in configuration names `user-with-personal-tasks`, the iOS bundle is `Official.PHS.Dev`, and functions are configured for `us-central1`. The Dev deployment verified the project, database instance name and URL, RTDB location (`us-central1`), eleven deployed Functions, Functions region, and hosting site. The exact billing plan and APNs configuration remain unverified.

From `functions/`, after an operator authenticates interactively:

```sh
firebase login
firebase projects:list
firebase database:instances:list --project user-with-personal-tasks
firebase functions:list --project user-with-personal-tasks
firebase hosting:sites:list --project user-with-personal-tasks
```

Before continuing, record the exact project ID, database instance URL/location, Blaze/billing status, deployed regions, hosting site, iOS app/bundle IDs, APNs key or certificate environment, and the production minimum-version/update gate. Replace the example project and database values below with those verified values.

Use Node 22, which is required by Admin 14 and supported by both the Gen2 backend and the Gen1 Firebase Auth deletion trigger, then install exactly the locked backend dependencies:

```sh
cd /Users/sharulshah/Documents/PHS-Connect-Development/functions
npm ci
npm run check
```

Automated app, backend, and rules test suites were removed at the owner's request. `npm run check` validates Node 22 and backend entry-point syntax only. Build the app and manually verify the staging flows below, including authorization, before rollout.

## Backup and dry run

Create a full RTDB export in addition to the migration tool's scoped backup. Keep backups encrypted and access-restricted because they include private user data.

```sh
firebase database:get / \
  --project user-with-personal-tasks \
  --instance user-with-personal-tasks-default-rtdb \
  > /absolute/secure/path/full-pre-calendar-v2.json

node scripts/migrate-calendar-v2.js \
  --project user-with-personal-tasks \
  --database-url https://user-with-personal-tasks-default-rtdb.firebaseio.com \
  > /absolute/secure/path/calendar-v2-dry-run.json
```

Firebase CLI login and Admin SDK application-default credentials are separate. If the operator has a valid Firebase CLI login but no Admin credential, export Auth and run the same validation entirely against the private exports:

```sh
firebase auth:export /absolute/secure/path/auth-pre-calendar-v2.json \
  --format=json \
  --project user-with-personal-tasks

node scripts/migrate-calendar-v2.js \
  --project user-with-personal-tasks \
  --database-export /absolute/secure/path/full-pre-calendar-v2.json \
  --auth-export /absolute/secure/path/auth-pre-calendar-v2.json \
  > /absolute/secure/path/calendar-v2-dry-run.json
```

Offline exports are intentionally read-only and cannot be combined with `--apply`. They can, however, produce a private scoped backup and a reviewed Firebase CLI-compatible atomic plan when Firebase CLI login is available but Admin application-default credentials are not:

```sh
node scripts/migrate-calendar-v2.js \
  --project user-with-personal-tasks \
  --database-export /absolute/secure/path/full-pre-calendar-v2.json \
  --auth-export /absolute/secure/path/auth-pre-calendar-v2.json \
  --scoped-backup /absolute/secure/path/calendar-v2-scoped-backup.json \
  --plan-output /absolute/secure/path/calendar-v2-atomic-plan.json
```

Before applying, verify that the plan has no ancestor/descendant path collisions, no `/clubs/{clubID}/meetingTimes` writes, no notification-job writes, and only `null` values for legacy `/users/{uid}/fcmToken` paths. Apply it as one update with triggers disabled:

```sh
firebase database:update / /absolute/secure/path/calendar-v2-atomic-plan.json \
  --force \
  --disable-triggers \
  --project user-with-personal-tasks \
  --instance user-with-personal-tasks-default-rtdb
```

There is no deployed per-club repair path. Conversion is operator-run with the offline migration tooling before the new-only client is released. Private repair records created during the original Dev incident remain audit evidence only.

Review every `malformedDates`, `missingRevisionTimestamps`, `unresolvedIdentities`, `unresolvedVisibility`, and `conflicts` entry. Malformed or ambiguous Chicago times block apply and are never substituted with the current time. When a valid meeting has no legacy revision timestamp, migration reports it and deterministically uses the meeting start for iCalendar revision metadata. Unresolved identities remain private reconciliation records and receive no access until Firebase Auth has a verified, enabled `@d214.org` account.

Repeat the dry run after reconciliation. Stable source-position-based meeting IDs preserve duplicate-looking legacy occurrences, and a rerun must report no canonical conflicts.

After migration, run the read-only readiness validator and retain its JSON output with the rollout evidence:

```sh
node scripts/validate-calendar-v2-readiness.js \
  --project user-with-personal-tasks \
  --database-url https://user-with-personal-tasks-default-rtdb.firebaseio.com
```

Without Admin credentials, first export the current database with `firebase database:get --export`, then pass `--database-export /absolute/secure/path/current.json` to the validator instead of `--database-url`.

See `DEV_TO_OFFICIAL_CALENDAR_V2_HANDOFF.md` before porting this implementation to the Official checkout.

## Coordinated new-version-only cutover

Previous app versions are unsupported. Keep the existing update-required gate, but enforce data ownership with backend authorization and RTDB rules rather than trusting that screen. Frozen legacy fields remain readable as children of public `/clubs`, so an old installation may display stale values; no backend or client code keeps them correct. Chat and other preserved direct-write features continue under their existing scoped rules.

1. Deploy the new HTTPS backend and authenticated meeting fallback. Do not invoke migration yet.
   The Functions target has a local predeploy hook that runs the backend test suite and aborts the deployment if a test fails.

   ```sh
   cd /Users/sharulshah/Documents/PHS-Connect-Development
   firebase deploy --only functions,hosting --project user-with-personal-tasks
   ```

2. Deploy `database.rules.json`. This is the write cutover: legacy clients cannot rewrite membership arrays or `/clubs/{clubID}/meetingTimes`, while the backend owns membership, meeting, RSVP, subscription, device, and read-state writes.

   ```sh
   firebase deploy --only database --project user-with-personal-tasks
   ```

3. Immediately run the migration with a new, nonexistent, absolute backup path. `--apply` also requires an exact project confirmation and refuses to write if malformed dates or conflicts remain. It migrates each club under the same per-club lock used by the updated backend, so already-converted clubs remain writable while later clubs are processed. An unconverted club rejects updated meeting edits until its conversion completes rather than risking loss of legacy meetings. If only Firebase CLI credentials are available, use the reviewed atomic-plan workflow in the previous section instead.

   ```sh
   cd /Users/sharulshah/Documents/PHS-Connect-Development/functions
   node scripts/migrate-calendar-v2.js \
     --apply \
     --project user-with-personal-tasks \
     --confirm-project user-with-personal-tasks \
     --database-url https://user-with-personal-tasks-default-rtdb.firebaseio.com \
     --backup /absolute/secure/path/calendar-v2-scoped-backup.json
   ```

4. Validate reciprocal membership roles and counts, unresolved reports, meeting counts/IDs, month overlap indexes, latest/minimum cursors, the unchanged frozen legacy fields, and removal of legacy `/users/{uid}/fcmToken`. Confirm every legacy targeted-visibility email has matching private forward/reverse reconciliation claims and completion evidence. Confirm migration notification suppression produced no meeting-notification jobs.
5. Exercise one test account in production-like staging: membership removal/rejoin, leader-only visibility, RSVP cutoff, token create/revoke/rotate, cold/warm/304 feed, device reinstall, two active devices, and notification acknowledgement.
6. Release the update-required app only after validation. Keep provider-refresh messaging explicit: calendar client updates/removals are not immediate. Retain frozen legacy values without updating them; do not delete them during this rollout.

## Post-cutover verification

- Repeat `npm run check`, build the release app, and manually verify the staging flows above against the release artifact.
- Confirm an unchanged conditional feed returns 304 after authorization/dependency checks and performs no meeting-body read.
- Confirm a warm 200 reads the private cached body, while a post-calendar-edit request rebuilds from bounded month indexes.
- Confirm notification routing reads message/chat scalars, `/clubMemberships/{clubID}`, targeted user preferences, and `/notificationDevices/{uid}`—never the full chat or `/users`.
- Confirm RSVP and read-state writes do not change club calendar cursors or feed fingerprints.
- Confirm account switching detaches old listeners and that another device sees monotonic acknowledgement without clearing a newer notification.
- Inspect Functions error/retry rates, RTDB reads/writes, cache storage, outbound feed bytes, FCM invalid-token cleanup, and change-log compaction before comparing production cost.

## Rollback

The scoped backup can be inspected safely without writing:

```sh
node scripts/rollback-calendar-v2.js \
  --project user-with-personal-tasks \
  --database-url https://user-with-personal-tasks-default-rtdb.firebaseio.com \
  --backup /absolute/secure/path/calendar-v2-scoped-backup.json
```

Before any new-format writes, an authorized operator can apply it with both explicit flags:

```sh
node scripts/rollback-calendar-v2.js \
  --apply \
  --project user-with-personal-tasks \
  --confirm-project user-with-personal-tasks \
  --database-url https://user-with-personal-tasks-default-rtdb.firebaseio.com \
  --backup /absolute/secure/path/calendar-v2-scoped-backup.json
```

Coordinate that data rollback with the previously audited functions, hosting, database rules, and compatible app-version gate. Restoring legacy data without compatible rules/backend leaves the application unusable.

Because the legacy meeting snapshot intentionally stops at cutover, it cannot be used alone to roll back after v2 writes. Keep v2 authoritative, export current data, and use an explicit reviewed conversion of canonical meetings if an emergency downgrade is ever required.

The rollback tool refuses an automatic rollback when it detects new-format writes after the migration marker. In that case, first export current data, leave the update gate active, and perform a reviewed forward repair or explicit merge; overwriting the database would discard meetings, memberships, RSVPs, subscription changes, or device state created after cutover.
