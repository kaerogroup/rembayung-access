# STATUS

Last updated: 2026-09-05

Slice A is implemented and production-connected.
Slice B scheduled random draw is COMPLETE — production runtime accepted.
Slice C Resend invitation delivery is COMPLETE for prototype acceptance — production Worker transport, retry/outbox state and token clearing were runtime verified.
Slice D authenticated invitation gate is COMPLETE — core authority and full human-visible golden-path production acceptance are now verified.

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

## Slice D / golden-path production acceptance

Implemented and production-applied:
- static-export-safe Rembayung invitation page at `/invitation?token=...`;
- authenticated `open_invitation(text)` PostgreSQL RPC;
- authenticated `redirect_invitation(text,text)` PostgreSQL RPC;
- token hashing and ownership checks remain server/database-side;
- expiry and revocation are revalidated before redirect eligibility;
- valid `issued` invitations transition idempotently to `opened`;
- UMAI destination is read from canonical `booking_sessions.umai_url`, not chosen by the browser;
- redirect actions are recorded in `redirect_audits`;
- new invitation emails point back to the Rembayung invitation gate rather than directly to UMAI.

Production verification migration `20260905000600_slice_d_runtime_acceptance.sql` applied successfully and proved valid-owner, wrong-owner, repeat-redirect and expiry boundaries.

Full end-to-end golden-path acceptance then completed using `[TEST] Golden Path — Invitation Gate` without a manual draw:
- user joined through the normal authenticated PWA flow at 10:16:36 MYT;
- natural Cloudflare Cron processed Wave 1 at 10:37:49 MYT with `selected_count = 1` and no error;
- the interest transitioned `active -> selected` exactly once;
- exactly one invitation and exactly one delivery were created;
- Resend delivery completed at 10:37:50 MYT with `attempt_count = 1`, provider message ID present, `last_error = null` and transient token cleared;
- the invitation route was opened by the authenticated owner at 10:46:03 MYT;
- the redirect boundary was exercised at 10:46:25 MYT;
- final invitation status is `redirected`;
- `redirect_audit_count = 1`;
- no duplicate invitation/entitlement was created.

Golden path is therefore COMPLETE / production runtime accepted.

## Active next focus

Move from single-entitlement technical acceptance to capacity-aware allocation while preserving random-first fairness:
- make party-size limits session-specific rather than globally assumed;
- configure the real Rembayung venue contract as 3–8 pax while keeping the platform reusable for other venues;
- introduce capacity-aware random allocation so total selected pax cannot exceed the session allocation budget;
- keep UMAI as final table/time/deposit/reservation authority;
- then run a larger fairness/idempotency acceptance with 100+ dummy interests before broadening the admin surface.
