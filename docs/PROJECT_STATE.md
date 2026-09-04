# PROJECT STATE

Last updated: 2026-09-05

## Current status

Rembayung Access is a production-connected MVP for fair access before UMAI.

Slice A is implemented. Slice B scheduled random draw is COMPLETE — production runtime accepted. Slice C Resend invitation delivery is the active product slice.

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
- Cloudflare Cron production diagnostic and Worker runtime tail diagnostic for focused operational debugging.

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

## Active product slice — Slice C Resend

Target:

- consume pending invitation delivery rows;
- send transactional invitation email through Resend from server/Worker runtime only;
- email returns the selected user to a Rembayung Access invitation URL, never directly to UMAI;
- record delivery provider result, provider message ID, attempt count, sent timestamp and bounded failure state;
- retry safely and idempotently;
- preserve Supabase as transactional authority;
- remain extensible for Supabase Realtime in-app updates and future Web Push notifications, with email as a reliable delivery channel.

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
