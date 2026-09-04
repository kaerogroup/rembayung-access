# Rembayung Access

Fair-access booking invitation layer for high-demand restaurant reservations.

## MVP golden path

1. User registers once.
2. User joins an interest pool for a dining session.
3. Scheduled draw selects eligible users using random-first allocation.
4. Invitations are broadcast automatically by batch/wave.
5. Email opens an authenticated invitation inside Rembayung Access.
6. Valid invitation redirects the selected user to UMAI.
7. UMAI remains the reservation, deposit, table, floor-plan and restaurant-operations authority for the MVP.

## Stack

- Next.js 16 + React 19 + TypeScript
- Supabase PostgreSQL + Auth
- Cloudflare Workers
- Cloudflare Cron Triggers for scheduled broadcast
- Resend for transactional email
- GitHub Actions for CI
- GitHub `main` as production source branch

## Source of truth

`origin/main` + Supabase migrations + canonical docs + verified production runtime.

## Development pipeline

`ChatGPT -> feature branch/PR -> GitHub Actions -> Cloudflare preview -> runtime check -> merge main -> Cloudflare production -> smoke verification -> project-state update`

## Canonical docs

- `docs/SSOT.md`
- `docs/CANON.md`
- `docs/ERD.md`
- `docs/FLOWS.md`
- `docs/ARCHITECTURE.md`

## Implementation slices

### Slice A — Foundation
- scaffold web app
- Supabase Auth
- apply foundation migration
- upcoming session list
- join/cancel interest

### Slice B — Scheduled draw
- scheduled waves
- Cloudflare Cron trigger
- idempotent random-first selection

### Slice C — Resend
- invitation email
- delivery outbox/retry

### Slice D — Invitation gate
- authenticated invitation page
- expiry + ownership validation
- audited UMAI redirect

### Slice E — Minimum admin
- create/publish session
- configure waves and UMAI destination
- observe pool/invitation/delivery counts

## Important MVP boundary

Rembayung Access controls fair access before UMAI. Once redirected, UMAI remains the final booking authority. Stronger transfer prevention requires an official UMAI handoff/integration or moving more reservation authority into Rembayung Access.
