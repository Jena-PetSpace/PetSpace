# Firebase/FCM production activation runbook

> Status: Firebase credentials, Edge deployment, Vault setup, release SQL, and
> server-side one-device delivery validation complete; visual receipt pending
> Security rule: never print or commit service-account JSON, service-role keys,
> device tokens, or user notification payloads.

## Current production facts (read-only audit)

- Android package: `com.jena.petspace`
- Firebase project ID: `project-5e5638c5-de70-498d-8f2`
- Firebase owner account found: `jena.k00002@gmail.com`
- Firebase Admin service account exists.
- Supabase project: `juukbctqzlrxfnivhgqe`
- `FIREBASE_SERVICE_ACCOUNT_KEY`: registered as an Edge secret
- `FIREBASE_PROJECT_ID`: registered as an Edge secret
- `send-push-notification`: deployed with JWT verification
- Database push settings: stored in Supabase Vault
- Local Flutter analyze and tests: passed
- Codex/Claude review: blocker/high 0

The push path is active. Keep the trigger enabled only while all five release
verification checks remain true.

## 2026-08-04 activation result

- release verification: function, trigger, URL Vault, service-role Vault all true
- Edge authorization boundary: unauthenticated 401, anon 403, service role 200
- smoke notification: exactly one canonical row created
- FCM result: one active Android token accepted; four stale tokens failed and
  were automatically deactivated
- delivery state: `is_sent=true`, `sent_at` recorded
- remaining manual check: confirm the visible notification and tap behavior on
  the physical device

## Activation order

Stop immediately when a step fails. Do not skip forward.

1. In Firebase Console, generate one new private key for the existing Firebase
   Admin service account. Keep the downloaded JSON outside the repository.
2. Validate only `project_id`, `client_email`, and key structure locally;
   never print the private key.
3. Register Supabase Edge secrets:
   - `FIREBASE_SERVICE_ACCOUNT_KEY` (store the outside-repository JSON as a
     single-line Base64 value when using the CLI)
   - `FIREBASE_PROJECT_ID`
   - `PUSH_AUTH_SERVICE_ROLE_KEY` (legacy service-role JWT used by the DB trigger)
4. Deploy `send-push-notification` with JWT verification enabled. Never use
   `--no-verify-jwt`.
5. Verify boundary behavior:
   - request without a JWT -> 401
   - valid non-service JWT -> 403
6. Run `supabase/releases/20260804_fcm_notification_release.sql` in Supabase
   Dashboard SQL Editor.
7. The project owner stores the private values in Supabase Vault as:
   - `petspace_supabase_url`
   - `petspace_service_role_key`
   Hosted Supabase does not grant the superuser permission required by this
   project for custom `ALTER DATABASE ... app.settings` values. Vault is the
   supported encrypted store and the values must not be stored in Git.
8. Open a fresh SQL Editor session and verify existence only.
9. Create exactly one test notification for a test account/device.
10. Verify `notifications.is_sent=true`, `sent_at`, and receipt on device.

## Real-device matrix

- app state: foreground / background / terminated
- type: like / comment / follow / chat / emotion analysis / health / system
- tap route: correct destination, no duplicate navigation
- preferences: all-off, type-off, permission denied and re-enabled
- token: logout disables, login registers, refresh replaces stale token
- Android channel: social / health / chat / system

## Rollback

Run the minimum required action and then verify from a fresh SQL session:

```sql
select vault.update_secret(
  (select id from vault.decrypted_secrets
   where name = 'petspace_service_role_key' limit 1),
  '',
  'petspace_service_role_key',
  'Disabled during notification rollback',
  null
);
```

For immediate trigger isolation only:

```sql
ALTER TABLE public.notifications
  DISABLE TRIGGER trg_push_on_notification;
```

Rotate a compromised Firebase key in Firebase/Supabase; never save it in the
repository. Do not resend the existing unsent backlog automatically.
