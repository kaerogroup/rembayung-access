# STATUS

Last updated: 2026-09-05

Slice A is implemented and production-connected.
Slice B scheduled random draw is COMPLETE — production runtime accepted.
Slice C Resend invitation delivery is COMPLETE for prototype acceptance — production Worker transport, retry/outbox state and token clearing were runtime verified.

## Slice B production acceptance

- authenticated interest persisted successfully;
- Cloudflare Cron fired without admin action;
- Wave 1 completed with `selected_count = 1`;
- the active interest became `selected` exactly once;
- exactly one invitation was created;
- Wave 2 completed with `selected_count = 0`;
- invitation count remained exactly one;
- both completed waves recorded no error.

Runtime defects found during Slice B acceptance were fixed through governed changes: the Worker uses the Supabase secret as an API key rather than a Bearer JWT, and `process_due_wave()` schema-qualifies Supabase `pgcrypto` routines under `extensions`.

## Slice C prototype acceptance

Implemented and production-deployed:
- retryable database-backed invitation delivery outbox;
- transient invitation token retained only while delivery remains actionable and cleared after send/expiry;
- service-role-only claim/complete/fail/expire delivery RPCs;
- bounded retries and stale-send reclaim;
- Resend transport with stable per-invitation idempotency key;
- governed Cloudflare deployment with `RESEND_API_KEY` kept server-only;
- prototype sender `onboarding@resend.dev`;
- prototype transport override to Resend test recipient `delivered@resend.dev`, while the authoritative recipient remains unchanged in the database.

Runtime evidence from `[TEST] Slice C — Resend Delivery Runtime`:
- authenticated interest entered the production pool;
- natural Cloudflare Cron selected the interest and issued exactly one invitation;
- an outbox row was created with a retryable transient token;
- initial sends to a real recipient were rejected by the Resend test-sender restriction and retried with bounded backoff;
- after the prototype test-recipient override was deployed, the same outbox row retried successfully;
- Resend recorded exactly one delivered test email at 2026-09-05 09:44:43 MYT;
- the delivery row transitioned to `sent` with `attempt_count = 5`, `last_error = null` and no retained invitation token;
- production checkpoint recorded `rows_retaining_token = 0` and no stuck `pending` or `sending` rows.

Production-hardening remains separate from prototype acceptance: before emailing real users, verify a custom sending domain, remove `RESEND_TEST_RECIPIENT`, use a domain-scoped sending key, and rotate the prototype API key.

Active slice: Slice D — authenticated invitation gate, ownership/expiry validation and audited UMAI redirect.
