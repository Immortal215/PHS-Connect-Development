# Super-admin claim rollout

The backend and RTDB rules authorize super administrators only when the authenticated Firebase ID token contains the boolean custom claim `phsSuperAdmin: true`. The iOS app uses that same claim to show admin controls. The email list in `functions/scripts/super-admin-emails.dev.json` is a one-time Development provisioning manifest, not runtime authority. Create a separate manifest with the exact Official project ID and intended accounts before any Official rollout.

Development now runs the claim-based `phsApi` and `phsAdmin` Functions and claim-based RTDB rules with the two verified admin accounts below. Frank remains pending by the owner's decision. His address in the one-time manifest grants no runtime access. For an Official rollout, provision and verify every intended administrator before switching server authority.

## Development status (2026-09-25)

The `phsSuperAdmin: true` claim was applied and verified for the Sharul and Devin accounts in the Development manifest. A fresh read-only Auth check confirmed both still hold verified accounts and claims, Frank has no Development Auth account, and there are no unexpected claim holders. The full three-account manifest cannot yet pass `plan` or `verify`. On September 25, `phsApi` was updated and `phsAdmin` was created in `user-with-personal-tasks`; both were verified `ACTIVE` on Node 22 in `us-central1`. The claim-based RTDB rules were deployed afterward and read back from Firebase; they exactly match `database.rules.json` and contain no old admin email allowlist. The two-account provisioning backup is an owner-only file at `/Users/sharulshah/Documents/phs-super-admin-claims-backup-2026-09-25.json`; retain it until rollout is stable. If those two claims must be reversed, use that backup with the `rollback` command below. Frank must create and verify an account before an existing admin can grant his claim.

The app's Administrators screen uses the authenticated `GET`, `PUT`, and `DELETE /admins` routes on the separate `phsAdmin` Function to list, grant, and remove Auth claims. It does not use the static manifest as a live list. Adding an email requires an existing, enabled Auth account with a verified email; Frank must sign up and verify his account first. A removal is reflected on the removed account's devices when their ID token refreshes; the management routes also check the current Auth record so a removed admin cannot use an old token to manage admins.

The September 25 Functions deployment used `firebase deploy --non-interactive --project user-with-personal-tasks --only functions:phsApi,functions:phsAdmin`; no other Functions or rules were selected. Both endpoints returned HTTP 401 without authentication after deployment. Before using the static manifest's `verify` command after an in-app addition, update its email list to include every intended admin; otherwise the verifier will correctly flag the new claim as unexpected.

The subsequent rules deployment used `firebase deploy --non-interactive --project user-with-personal-tasks --only database`. A focused local RTDB emulator test passed for claimed and unclaimed admins, verified members, leader/chat writes, and blocked legacy meeting and membership writes. The live rules readback confirmed that the hard-coded Frank, Sharul, and Devin email exceptions were removed. Existing Firebase ID tokens may retain an old claim until refresh or expiry; the app refreshes its token on foreground activation.

Run these commands from `functions/` with Node 22 and credentials for the exact target project. Review the manifest and `--project` value first. `plan` and `verify` only read Auth accounts; `bootstrap` and `rollback` change custom claims. The backup is written with owner-only permissions and must be kept outside the repository.

```sh
node scripts/super-admin-claims.js plan --project user-with-personal-tasks --emails scripts/super-admin-emails.dev.json
node scripts/super-admin-claims.js bootstrap --project user-with-personal-tasks --confirm-project user-with-personal-tasks --emails scripts/super-admin-emails.dev.json --backup /private/tmp/phs-super-admin-claims-backup.json
node scripts/super-admin-claims.js verify --project user-with-personal-tasks --emails scripts/super-admin-emails.dev.json
```

`bootstrap` checks all intended accounts are enabled and verified and rejects any unexpected existing admin claim before writing a backup or changing a claim. `verify` fails if any intended account lacks the claim or another UID has it. Make the claim-aware iOS build available to admins before switching server authority. After provisioning, each admin can bring that build to the foreground: it forces an ID-token refresh when the app becomes active, so signing out is unnecessary. Confirm their refreshed token contains the claim and the admin controls appear. For an Official rollout, deploy Functions and then RTDB rules after completing its separate claim audit. An older build cannot perform this claim-aware check; update it before the authority switch or refresh its token separately. Repeat the claim and rule tests against the release candidate. Keep the backup until the rollout is stable.

If this Development rollout must be reversed, review the Functions and rules together before restoring claims. Restoring the old email-allowlist rules would regrant direct database permissions to those addresses, including Frank's, and should not be used as an automatic rollback. After compatible server authority is established, restore claims from the saved backup if needed:

```sh
node scripts/super-admin-claims.js rollback --project user-with-personal-tasks --confirm-project user-with-personal-tasks --backup /Users/sharulshah/Documents/phs-super-admin-claims-backup-2026-09-25.json
```

Rollback restores only the `phsSuperAdmin` claim and preserves unrelated current custom claims. If an Auth account or its claim changed unexpectedly, rollback stops before any writes so an operator can review the account. A partial bootstrap can be rolled back with the same backup. The CLI never deploys code or rules.
