# PROJECT STATE

Last updated: 2026-09-05

## Current status

Rembayung Access is a production-connected MVP for fair access before UMAI.

Slice A is implemented. Slice B scheduled random draw is COMPLETE — production runtime accepted. Slice C Resend invitation delivery is IMPLEMENTED / DEPLOYED, with production email acceptance waiting only on Resend configuration and a fresh acceptance invitation.

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
- Governed Cloudflare broadcast Worker deployment from `main` when worker/deployment files change.
- Read-only Slice B production runtime checkpoint through GitHub Actions.
- Read-only Slice C production delivery checkpoint through GitHub Actions.
- Cloudflare Cron production diagnostic and Worker runtime tail diagnostic for focused operational debugging.
- Slice C retryable invitation email outbox and Resend Worker transport deployed to production.

## Slice B — COMPLETE / production runtime accepted

Fixed acceptance session:

`4e690585-4986-48d9-a6cb-1a0d168fd06f` — `[TEST] Slice B — Random Draw Runtime`

Verified production evidence:

1. authenticated user joined one interest with party size 2;
2. Cloudflare Cron invocation was captured in production without admin-triggered draw execution;
3. Wave 1 transitioned to `completed` at 2026-09-05 07:51:45 MYT with `selected_count = 1`;
4. the sole eligible interest transitioned `active -> selected` exactly once;
5. exactly one invitation was created;
6. Wave 2 transitioned to `completed` at 2026-09-05 07:52:45 MYT with `selected_count = 0`;
7. invitation total remained exactly one after Wave 2, proving no duplicate entitlement for the accepted scenario;
8. both completed waves recorded no error.

During runtime acceptance, focused diagnostics identified two integration defects and corrected them through governed changes:

- the Cloudflare Worker no longer sends the Supabase opaque secret key as a Bearer JWT; it uses the server-only API-key header boundary;
- `process_due_wave()` schema-qualifies Supabase `pgcrypto` routines under `extensions` via migration `20260905000200_fix_slice_b_pgcrypto_schema.sql`, while retaining the restricted function search path.

No manual draw RPC was used for final acceptance; the successful transitions were produced by the production Cloudflare Cron path.

## Slice C — IMPLEMENTED / DEPLOYED / production acceptance pending configuration

Implemented authority and delivery behavior:

- migration `20260905000300_slice_c_resend_delivery_outbox.sql` adds retryable outbox state;
- invitation plaintext token is retained only in the RLS-protected delivery row while delivery is pending/retryable and is cleared after successful send or expiry;
- pre-Slice-C pending rows that cannot reconstruct plaintext token are retired explicitly rather than retried incorrectly;
- `claim_pending_email_delivery()` claims one actionable delivery with row locking and stale-send reclaim;
- `complete_email_delivery()` records provider result and clears the transient token;
- `fail_email_delivery()` records bounded error state and schedules retry backoff;
- `expire_email_deliveries()` retires expired unsent delivery payloads;
- all delivery mutation RPCs are service-role-only;
- Broadcast Worker drains up to a bounded number of deliveries per Cron tick;
- Resend request uses a stable per-invitation idempotency key;
- operational logs do not expose recipient emails or plaintext invitation tokens;
- invitation email returns the user to a Rembayung Access invitation route, never directly to UMAI;
- Worker remains healthy and leaves outbox state untouched when Resend production configuration is incomplete.

Production deployment evidence:

- Slice C Supabase migration dry-run PASS;
- Slice C production migration apply PASS;
- Broadcast Worker deployment PASS;
- Slice C runtime checkpoint PASS;
- current outbox has one legacy pre-Slice-C row, safely `failed` with `attempt_count = 0` and no retained plaintext token;
- production Cron tail captured `outcome: ok` with no exception;
- production Worker reported `Invitation email delivery inactive: Resend production configuration is incomplete`;
- governed Worker deployment subsequently selected the safe `without Resend` path because the required production values were not complete.

Active production acceptance boundary:

1. configure all three values in the GitHub `production` environment: `RESEND_API_KEY`, `RESEND_FROM_EMAIL`, `APP_BASE_URL`;
2. governed Worker deploy must select the `with Resend` path;
3. issue a fresh invitation through the existing draw authority so the outbox receives a valid transient token;
4. verify `pending -> sending -> sent`, one provider message ID, bounded attempt count and token clearing;
5. repeat the runtime checkpoint to prove no duplicate send or stuck claim.

Do not reconstruct or reuse the pre-Slice-C invitation token; only a fresh invitation can prove Slice C correctly.

## Subsequent slices

### Slice D — Invitation gate
- invitation page inside Rembayung Access;
- authenticated ownership and expiry validation;
- audited redirect to configured UMAI destination.

### Slice E — Minimum admin
- create/publish sessions;
- configure draw/wave parameters and UMAI destination;
- observe pool, wave, invitation and delivery state.

## Source of truth

`origin/main + Supabase migrations + canonical docs + verified production runtime`

## Delivery posture

Use focused branch/PR changes, CI/dry-run gates, governed production apply/deploy and runtime acceptance. Do not repeat broad audits when the authoritative checkpoints are already green.

## Guardrails

- Rembayung Access controls fair access before UMAI; UMAI remains final reservation authority in MVP.
- No payment integration yet.
- No QR/device binding yet.
- No advanced anti-fraud/risk scoring yet.
- PWA/offline state never becomes transactional authority.
