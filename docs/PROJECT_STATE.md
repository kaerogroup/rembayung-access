# PROJECT STATE

Last updated: 2026-09-05

## Current status

Rembayung Access is a production-connected MVP for fair access before UMAI.

Slice A is implemented. Slice B scheduled random draw is COMPLETE — production runtime accepted. Slice C Resend invitation delivery is COMPLETE for prototype runtime acceptance. Slice D authenticated invitation gate is COMPLETE — core authority and full end-to-end golden-path production acceptance are verified.

The active focus is now capacity-aware fair allocation: session-specific party-size constraints plus pax-budget-aware random-first selection, followed by larger fairness/idempotency acceptance.

## Completed / operational

- Repository identity and canonical documentation: README, SSOT, Canon, ERD, Flows and Architecture.
- Mobile-first / PWA-first Next.js customer surface.
- Supabase Auth registration/login.
- Published session listing.
- Authenticated join/cancel interest RPCs with server-side eligibility checks.
- PostgreSQL authority for sessions, interests, draw waves, invitations, email delivery outbox and redirect audits.
- Idempotent draw-wave materialization via `ensure_draw_waves()`.
- Server-only random-first selection via `process_due_wave()`.
- Cloudflare broadcast Worker deployed with every-minute Cron trigger.
- GitHub Actions CI on pull requests and `main`.
- Supabase migration dry-run gate on PRs and governed migration apply on `main`.
- Governed Cloudflare broadcast Worker deployment from `main`.
- Read-only production runtime checkpoints through GitHub Actions.
- Cloudflare Cron and Worker runtime-tail diagnostics for focused operational debugging.
- Retryable Slice C invitation email outbox and Resend Worker transport deployed and prototype-accepted.
- Static-export-safe Slice D invitation surface at `/invitation?token=...`.
- Authenticated PostgreSQL invitation open and redirect authority with redirect auditing.
- Full normal-flow production golden path accepted from PWA interest join through natural Cron draw, Resend delivery, authenticated invitation open and audited downstream redirect.

## Slice B — COMPLETE / production runtime accepted

Fixed acceptance session:

`4e690585-4986-48d9-a6cb-1a0d168fd06f` — `[TEST] Slice B — Random Draw Runtime`

Verified production evidence:

1. authenticated user joined one interest;
2. Cloudflare Cron invocation executed without admin-triggered draw execution;
3. Wave 1 completed at 2026-09-05 07:51:45 MYT with `selected_count = 1`;
4. the sole eligible interest transitioned `active -> selected` exactly once;
5. exactly one invitation was created;
6. Wave 2 completed at 2026-09-05 07:52:45 MYT with `selected_count = 0`;
7. invitation total remained exactly one after Wave 2;
8. both completed waves recorded no error.

Focused acceptance diagnostics also corrected the Supabase secret-key auth boundary and schema-qualified Supabase `pgcrypto` routines under `extensions` through migration `20260905000200_fix_slice_b_pgcrypto_schema.sql`.

No manual draw RPC was used for final acceptance.

## Slice C — COMPLETE / prototype runtime accepted

Authority and delivery behavior:

- migration `20260905000300_slice_c_resend_delivery_outbox.sql` adds retryable outbox state;
- invitation plaintext token is retained only in the RLS-protected delivery row while delivery is actionable and is cleared after successful send or expiry;
- pre-Slice-C rows without reconstructable plaintext are explicitly retired;
- `claim_pending_email_delivery()` uses row locking, bounded retry eligibility and stale-send reclaim;
- `complete_email_delivery()` records provider completion and clears the transient token;
- `fail_email_delivery()` records errors and schedules bounded retry backoff;
- `expire_email_deliveries()` retires expired unsent payloads;
- delivery mutation RPCs are service-role-only;
- Broadcast Worker drains a bounded number of deliveries per Cron tick;
- Resend uses a stable per-invitation idempotency key;
- operational logs do not expose recipient emails or plaintext invitation tokens;
- invitation email points back to Rembayung Access rather than UMAI.

Prototype acceptance session:

`9e7e5bf7-2f4b-4e50-a7b1-dc28c1dfe3a7` — `[TEST] Slice C — Resend Delivery Runtime`

Verified production evidence:

1. authenticated interest entered the test session through the existing customer PWA flow;
2. natural Cloudflare Cron selected the interest and created exactly one invitation/outbox delivery;
3. initial Resend attempts were rejected because `onboarding@resend.dev` cannot send to arbitrary real recipients;
4. prototype-only `RESEND_TEST_RECIPIENT=delivered@resend.dev` was introduced while leaving the authoritative recipient unchanged in PostgreSQL;
5. the same retryable delivery was claimed again by natural Cron and Resend accepted exactly one test email;
6. Resend recorded the test message as `delivered` at 2026-09-05 09:44:43 MYT;
7. the outbox row transitioned to `sent` at 2026-09-05 09:44:43 MYT with `attempt_count = 5` and `last_error = null`;
8. `invitation_token` was cleared after completion;
9. runtime checkpoint at 2026-09-05 09:45:48 MYT reported `rows_retaining_token = 0`, `pending = 0`, `sending = 0` and one sent Slice C delivery;
10. the only other failed delivery is the intentionally retired pre-Slice-C legacy row with no retained plaintext token.

This closes prototype delivery acceptance, not real-user sender-domain hardening. Before production email to real users:

- verify a custom sending domain;
- remove the `RESEND_TEST_RECIPIENT` prototype override;
- rotate the prototype Resend API key and prefer a domain-scoped sending-only key;
- perform one real-domain delivery acceptance.

## Slice D — COMPLETE / production golden path accepted

Core implementation:

- migration `20260905000500_slice_d_invitation_gate.sql` adds authenticated invitation authority;
- `/invitation?token=...` is static-export-safe so Cloudflare Pages can serve it without moving transactional authority into static client code;
- `open_invitation(text)` hashes the supplied token inside PostgreSQL and resolves only an invitation owned by `auth.uid()`;
- expired invitations transition to `expired`; revoked invitations remain non-actionable;
- valid `issued` invitation transitions idempotently to `opened`;
- `redirect_invitation(text,text)` revalidates token, owner and expiry before reading canonical `booking_sessions.umai_url`;
- browser never chooses the downstream destination;
- valid redirect transitions the invitation to `redirected` and inserts `redirect_audits`;
- verification migration `20260905000600_slice_d_runtime_acceptance.sql` proved valid-owner, wrong-owner, repeat-redirect and expiry behavior in production.

Golden-path acceptance session:

`f0cc7c5e-5812-47c9-a405-aed71cb4eb73` — `[TEST] Golden Path — Invitation Gate`

Verified end-to-end production evidence:

1. authenticated PWA interest joined at 2026-09-05 10:16:36 MYT;
2. natural Cloudflare Cron processed Wave 1 at 10:37:49 MYT with `selected_count = 1` and `error_message = null`;
3. the sole interest transitioned `active -> selected` exactly once;
4. exactly one invitation and exactly one delivery were created;
5. delivery reached `sent` at 10:37:50 MYT with `attempt_count = 1`, provider message ID present and `last_error = null`;
6. delivery retained no plaintext invitation token after completion;
7. Resend recorded the matching prototype message as delivered;
8. the authenticated owner opened the Rembayung invitation route at 10:46:03 MYT;
9. the redirect boundary executed at 10:46:25 MYT;
10. final invitation status is `redirected`;
11. `redirect_audit_count = 1`;
12. no duplicate entitlement was created.

The golden path is therefore COMPLETE / production runtime accepted.

## Active focus — capacity-aware fair allocation

The current global party-size assumption is not sufficient for a reusable scarce-capacity platform. Venue/session policy must be explicit.

Implementation direction:

1. add session-specific `min_party_size` and `max_party_size` with backward-compatible defaults;
2. validate `join_interest()` against the session's configured range;
3. configure real Rembayung sessions for 3–8 pax, based on the current UMAI venue flow;
4. add a session allocation budget expressed in pax, separate from UMAI's final table inventory;
5. preserve random-first fairness while selecting only candidates whose party size fits the remaining budget;
6. keep PostgreSQL as winner authority and maintain idempotent invitation issuance;
7. verify mixed party-size, exact-fit, leftover-capacity and repeated-processing behavior with focused SQL tests;
8. then run a larger fairness/idempotency acceptance with 100+ dummy interests.

This is capacity allocation, not table allocation. UMAI remains final authority for actual date/time/table availability, deposit, cashless payment and confirmed reservation.

## Subsequent work

### Slice E — Minimum admin
- create/publish sessions;
- configure party-size range, allocation budget, draw/wave parameters and downstream destination;
- observe pool, wave, invitation and delivery state.

### Notification projection
- foreground Supabase Realtime first;
- later Web Push for closed/background PWA;
- PostgreSQL remains transactional authority.

### Later optimization
- controlled multi-wave replenishment from expired/unused entitlement capacity;
- standby/reallocation;
- optional slot preference and flexible-slot demand shaping;
- conversion analytics;
- data-driven recommendations only after enough runtime evidence exists.

## Source of truth

`origin/main + Supabase migrations + canonical docs + verified production runtime`

## Delivery posture

Use focused branch/PR changes, CI/dry-run gates, governed production apply/deploy and runtime acceptance. Do not repeat broad audits when authoritative checkpoints are already green.

## Guardrails

- Rembayung Access controls fair access before UMAI; UMAI remains final reservation authority in MVP.
- Invitation is not a confirmed reservation.
- No payment integration yet.
- No QR/device binding yet.
- No advanced anti-fraud/risk scoring yet.
- PWA/offline state never becomes transactional authority.
