# PROJECT STATE

Last updated: 2026-09-04

## Current status

Repository bootstrapped on `main`.

### Completed
- README and repository identity
- SSOT / Canon / ERD / Flows / Architecture
- Supabase foundation migration
- Cloudflare scheduled broadcast Worker skeleton
- GitHub Actions foundation CI
- Gated manual Cloudflare deployment workflow

### Current source of truth

`origin/main + Supabase migrations + canonical docs + verified runtime`

### Active next slice

**Slice A — Foundation**

- scaffold web application
- wire Supabase Auth
- upcoming sessions
- join/cancel interest
- migrate CI from foundation-only checks to lint/typecheck/test/build
- connect Cloudflare preview/production deployment

### Deployment state

Cloudflare credentials and runtime secrets are not yet configured. `deploy-cloudflare.yml` is intentionally `workflow_dispatch` only until the Cloudflare account/project is connected and the first deployment passes.

### Do not do

- no large audit before Slice A
- no UMAI replacement
- no payment integration
- no QR/device binding yet
