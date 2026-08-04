# Production release SQL

Current file to run in Supabase Dashboard SQL Editor:

`20260804_fcm_notification_release.sql`

Prerequisites:

1. `FIREBASE_SERVICE_ACCOUNT_KEY` is registered as a Supabase Edge secret.
2. `FIREBASE_PROJECT_ID` is registered as a Supabase Edge secret.
3. `send-push-notification` is deployed with JWT verification.
4. An unauthenticated request returns 401 and a non-service JWT returns 403.

The SQL is idempotent and contains no secret values. After it runs, the final
verification row must show the notification function and trigger as true.
The two database setting columns remain false until the project owner runs the
secret-bearing `ALTER DATABASE` statements from the private deployment step.

Never paste a service-role key into a tracked SQL file.
