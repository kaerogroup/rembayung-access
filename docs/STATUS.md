# STATUS

Last updated: 2026-09-05

Slice A is implemented and production-connected.
Slice B scheduled random draw is COMPLETE — production runtime accepted.
Slice C Resend invitation delivery is COMPLETE for prototype acceptance — production Worker transport, retry/outbox state and token clearing were runtime verified.
Slice D authenticated invitation gate is COMPLETE for core authority acceptance — production database validation, state transitions and audited redirect boundaries were verified.

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

## Slice D core authority acceptance

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

Production verification migration `20260905000600_slice_d_runtime_acceptance.sql` applied successfully. Its assertions verified against the production database:
- valid owner resolves the token and reaches `opened`;
- wrong owner resolves zero rows for the same valid token;
- valid redirect returns the canonical configured destination and records an audit;
- repeated redirect returns the same destination without creating a new entitlement and is independently audited;
- expired invitation becomes `expired`, returns no redirect destination and creates no further redirect audit;
- all temporary acceptance fixture rows are removed before migration commit.

The PWA invitation route passed typecheck, build and static-output CI. Direct independent inspection of the Cloudflare Pages route was not available through the current tooling, so page-level golden-path production acceptance remains the next checkpoint rather than being implied.

Active checkpoint: complete end-to-end golden-path acceptance using a fresh invitation: join -> scheduled draw -> email delivery -> open in Rembayung -> authenticated validation -> UMAI redirect boundary.
