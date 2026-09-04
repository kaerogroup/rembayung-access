# CI/CD

## Golden path

`ChatGPT -> feature branch -> pull request -> GitHub Actions -> focused runtime/preview checkpoint -> squash merge main -> governed production apply/deploy -> production smoke/runtime verification -> project-state update`

## Current production delivery state

- GitHub `main` is the production source branch.
- CI runs on pull requests and pushes to `main`.
- Supabase migration dry-run is the required schema checkpoint before governed apply.
- Migrations merged to `main` trigger the governed `Supabase Migration Apply` workflow.
- The Cloudflare broadcast Worker is deployed separately from the static customer PWA.
- Changes under `workers/broadcast/**` or its deployment workflow trigger governed production Worker deployment from `main`.
- The broadcast Worker uses a Cloudflare Cron Trigger and server-only Supabase credentials.
- A read-only Slice B runtime checkpoint workflow can inspect production session, interest, wave and invitation state through the existing governed Supabase connection.
- Cloudflare Pages hosts the static/mobile-first PWA customer surface; transactional authority remains in Supabase.

## Required GitHub Actions configuration

Repository variables include the public Supabase application configuration and production project reference used by the workflows.

Repository secrets include the Cloudflare deployment credentials and privileged Supabase credentials required by governed migration/runtime workflows.

Runtime application secrets, Supabase privileged credentials and future Resend API keys are server/worker only and must never be committed or exposed to the browser bundle.

## Delivery boundaries

### Customer PWA

- Next.js static/PWA surface delivered through Cloudflare Pages.
- Browser uses public Supabase configuration only.
- Authenticated customer writes use RLS/RPC boundaries.
- Offline/cache state is never authoritative for interests, draws or invitations.

### Supabase production

- Schema and stored procedures are changed only through committed migrations.
- PR dry-run is the pre-merge schema gate.
- `main` performs governed migration apply.

### Broadcast Worker

- Deployed independently because scheduler/background runtime has different authority and secrets from the static PWA.
- Calls `ensure_draw_waves()` and `process_due_wave()` using server-only credentials.
- Cron execution must remain idempotent and browser-independent.

## Runtime acceptance discipline

A green deployment is necessary but is not sufficient to close a product slice.

For each slice, verify the smallest authoritative runtime outcome. For Slice B this means:

1. authenticated participant joins the production test pool;
2. due wave is processed by the scheduled Worker without admin action;
3. random-first selection changes the eligible interest to `selected`;
4. invitation is created;
5. wave completes with the expected selected count;
6. repeated scheduler execution does not duplicate entitlement.

Use GitHub Actions/runtime evidence as checkpoints. Do not repeat a broad repository audit before every slice when source, migration and runtime checkpoints are aligned.
