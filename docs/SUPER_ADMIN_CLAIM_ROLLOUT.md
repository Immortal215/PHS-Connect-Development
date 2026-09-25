# Super-admin claim rollout

The backend and RTDB rules authorize super administrators only when the authenticated Firebase ID token contains the boolean custom claim `phsSuperAdmin: true`. The iOS app uses that same claim to show admin controls. The email list in `functions/scripts/super-admin-emails.dev.json` is a one-time Development provisioning manifest, not runtime authority. Create a separate manifest with the exact Official project ID and intended accounts before any Official rollout.

Do not deploy the claim-based Functions or RTDB rules until every intended admin has been provisioned and verified. This repository change does not provision accounts or deploy rules.

Run these commands from `functions/` with Node 22 and credentials for the exact target project. Review the manifest and `--project` value first. `plan` and `verify` only read Auth accounts; `bootstrap` and `rollback` change custom claims. The backup is written with owner-only permissions and must be kept outside the repository.

```sh
node scripts/super-admin-claims.js plan --project user-with-personal-tasks --emails scripts/super-admin-emails.dev.json
node scripts/super-admin-claims.js bootstrap --project user-with-personal-tasks --confirm-project user-with-personal-tasks --emails scripts/super-admin-emails.dev.json --backup /private/tmp/phs-super-admin-claims-backup.json
node scripts/super-admin-claims.js verify --project user-with-personal-tasks --emails scripts/super-admin-emails.dev.json
```

`bootstrap` checks all intended accounts are enabled and verified and rejects any unexpected existing admin claim before writing a backup or changing a claim. `verify` fails if any intended account lacks the claim or another UID has it. Make the claim-aware iOS build available to admins before switching server authority. After provisioning, each admin can bring that build to the foreground: it forces an ID-token refresh when the app becomes active, so signing out is unnecessary. Confirm their refreshed token contains the claim and the admin controls appear, then deploy the Functions and finally the RTDB rules. An older build cannot perform this claim-aware check; update it before the authority switch or refresh its token separately. Repeat the claim and rule tests against the release candidate. Keep the backup until the rollout is stable.

If the rollout must be reversed, first restore the previous email-authorized Functions and RTDB rules, then restore claims from the saved backup:

```sh
node scripts/super-admin-claims.js rollback --project user-with-personal-tasks --confirm-project user-with-personal-tasks --backup /private/tmp/phs-super-admin-claims-backup.json
```

Rollback restores only the `phsSuperAdmin` claim and preserves unrelated current custom claims. If an Auth account or its claim changed unexpectedly, rollback stops before any writes so an operator can review the account. A partial bootstrap can be rolled back with the same backup. The CLI never deploys code or rules.
