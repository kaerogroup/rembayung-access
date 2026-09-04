# PROJECT STATE

Last updated: 2026-09-05

## Current status

Rembayung Access is a production-connected MVP for fair access before UMAI.

Slice A is implemented. Slice B scheduled random draw is implemented and deployed; production runtime acceptance is the active checkpoint.

## Completed / operational

- Repository identity and canonical documentation: README, SSOT, Canon, ERD, Flows and Architecture.
- Mobile-first / PWA-first Next.js customer surface.
- Supabase Auth registration/login.
- Published session listing.
- Authenticated join/cancel interest RPCs with server-side eligibility checks.
- PostgreSQL authority for sessions, interests, draw waves, invitations, email delivery outbox and redirect audits.
- Idempotent draw-wave materialization via `ensure_draw_waves()`.
- Server-only random-first selection via `process_due_wave()`.
- Cloudflare broadcast Worker deployed with Cron trigger.
- GitHub Actions CI on pull requests and `main`.
- Supabase migration dry-run gate on PRs and governed migration apply on `main`.
- Governed Cloudflare broadcast Worker deployment from `main` when worker/deployment files change.
- Read-only Slice B production runtime checkpoint through GitHub Actions.

## Active runtime checkpoint — Slice B

Fixed test session:

`4e690585-4986-48d9-a6cb-1a0d168fd06f` — `[TEST] Slice B — Random Draw Runtime`

Acceptance proof required:

1. authenticated user joins the interest pool;
2. scheduled Cloudflare Cron processes the due wave without admin action;
3. exactly one eligible interest is selected for `wave_size = 1`;
4. one invitation is created;
5. wave completes with `selected_count = 1`;
6. retry/repeated scheduler execution does not duplicate entitlement.

The latest production checkpoint before participant join showed the session published, both waves scheduled, zero errors, zero interests and zero invitations.

## Next product slices

### Slice C — Resend
- consume pending invitation delivery rows;
- send transactional invitation email;
- record delivery result and retry safely.

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
