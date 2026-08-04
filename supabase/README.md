# PetSpace Supabase SQL layout

SQL files are separated by purpose so that a historical patch is never
mistaken for the current production apply file.

| Path | Purpose | Run on the current production project? |
|---|---|---|
| `petspace_setup.sql` | Legacy consolidated bootstrap snapshot; not yet a fully replayable current schema | No |
| `migrations/` | Timestamped migrations tracked by Supabase CLI | Only through an approved migration workflow |
| `releases/` | A reviewed, release-specific Dashboard apply file | Yes, only the file named in its README |
| `manual_sql/history/` | Historical Dashboard patches kept for audit and tests | No |
| `../docs/qa/*.sql` | Read-only inventory or verification queries | Read-only only |

## Current production apply file

For the 2026-08-04 FCM release, use:

`releases/20260804_fcm_notification_release.sql`

Do not run it until both Firebase Edge secrets are registered and
`send-push-notification` is deployed with JWT verification. The final
secret-bearing database settings remain a separate owner action and must never
be committed to Git.

## Rules

1. Never run `petspace_setup.sql` against an existing production database. A
   fresh-project rebuild also requires a reviewed schema reconciliation first.
2. Never run every file under `manual_sql/history/` in sequence.
3. New schema changes use a timestamped file in `migrations/` first.
4. A release apply file must be idempotent, scoped, reviewed, and contain no
   production key, token, email export, or user data.
5. Production SQL is executed by the project owner after a read-only drift
   check and explicit approval.
