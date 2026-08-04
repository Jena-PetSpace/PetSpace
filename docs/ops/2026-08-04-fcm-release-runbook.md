# Firebase/FCM production activation runbook

> Status: local implementation and review complete; production activation pending
> Security rule: never print or commit service-account JSON, service-role keys,
> device tokens, or user notification payloads.

## Current production facts (read-only audit)

- Android package: `com.jena.petspace`
- Firebase project ID: `project-5e5638c5-de70-498d-8f2`
- Firebase owner account found: `jena.k00002@gmail.com`
- Firebase Admin service account exists.
- Supabase project: `juukbctqzlrxfnivhgqe`
- `FIREBASE_SERVICE_ACCOUNT_KEY`: not registered
- `FIREBASE_PROJECT_ID`: not registered
- `send-push-notification`: not deployed
- Database push settings: not configured
- Local Flutter analyze and tests: passed
- Codex/Claude review: blocker/high 0

The push path is not active yet. This is intentional: database triggers must
not be armed before Firebase credentials and the Edge Function are verified.

## Activation order

Stop immediately when a step fails. Do not skip forward.

1. In Firebase Console, generate one new private key for the existing Firebase
   Admin service account. Keep the downloaded JSON outside the repository.
2. Validate only `project_id`, `client_email`, and key structure locally;
   never print the private key.
3. Register Supabase Edge secrets:
   - `FIREBASE_SERVICE_ACCOUNT_KEY`
   - `FIREBASE_PROJECT_ID`
4. Deploy `send-push-notification` with JWT verification enabled. Never use
   `--no-verify-jwt`.
5. Verify boundary behavior:
   - request without a JWT -> 401
   - valid non-service JWT -> 403
6. Run `supabase/releases/20260804_fcm_notification_release.sql` in Supabase
   Dashboard SQL Editor.
7. The project owner runs the private `ALTER DATABASE` statements for:
   - `app.settings.supabase_url`
   - `app.settings.service_role_key`
   These values must not be stored in Git or copied into this runbook.
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
ALTER DATABASE postgres RESET "app.settings.service_role_key";
```

For immediate trigger isolation only:

```sql
ALTER TABLE public.notifications
  DISABLE TRIGGER trg_push_on_notification;
```

Rotate a compromised Firebase key in Firebase/Supabase; never save it in the
repository. Do not resend the existing unsent backlog automatically.
