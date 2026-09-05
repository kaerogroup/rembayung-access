# STATUS

Last updated: 2026-09-05

Slice A is implemented and production-connected.
Slice B scheduled random draw is COMPLETE — production runtime accepted.

Production acceptance evidence:
- authenticated interest persisted successfully;
- Cloudflare Cron fired without admin action;
- Wave 1 completed with `selected_count = 1`;
- the active interest became `selected` exactly once;
- exactly one invitation was created;
- Wave 2 completed with `selected_count = 0`;
- invitation count remained exactly one, confirming no duplicate entitlement;
- both completed waves recorded no error.

Runtime defect discovered during acceptance was fixed through governed migration: `process_due_wave()` now schema-qualifies Supabase `pgcrypto` routines under `extensions` while retaining the restricted function search path.

Slice C — Resend invitation delivery is IMPLEMENTED / DEPLOYED; production email acceptance is pending configuration.

Implemented and production-deployed:
- retryable database-backed invitation delivery outbox;
- transient invitation token retained only while delivery is pending/retryable and cleared after send/expiry;
- service-role-only claim/complete/fail/expire delivery RPCs;
- bounded retries and stale-send reclaim;
- Resend transport with stable per-invitation idempotency key;
- read-only Slice C production runtime checkpoint;
- governed Cloudflare deployment path that enables Resend only when all required production secrets are present.

Latest production evidence:
- Slice C migration apply PASS;
- Broadcast Worker deploy PASS;
- Worker Cron runtime outcome `ok`;
- existing pre-Slice-C delivery was safely retired with no plaintext token retained;
- production Worker reports `Invitation email delivery inactive: Resend production configuration is incomplete`;
- governed deploy selected the `without Resend` path because required production configuration is not yet complete.

Active checkpoint: configure `RESEND_API_KEY`, `RESEND_FROM_EMAIL`, and `APP_BASE_URL` in the GitHub `production` environment, deploy through the governed workflow, then verify a new invitation email reaches `sent` exactly once.
