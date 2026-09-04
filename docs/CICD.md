# CI/CD

## Golden path

`ChatGPT -> feature branch -> pull request -> GitHub Actions -> Cloudflare preview -> runtime acceptance -> merge main -> Cloudflare production -> smoke verification`

## Current bootstrap state

- CI runs on pull requests and pushes to `main`.
- Supabase migration dry-run is the required schema checkpoint before governed apply.
- Frontend Slice A is a browser-only Next.js surface and is exported as static assets for Cloudflare Pages.
- Cloudflare production deployment remains manual until the first runtime deployment and smoke test pass.
- Broadcast scheduling remains a separate Cloudflare Worker deployment.
- After first runtime acceptance, production deployment can be enabled on push to `main` and preview deployment on pull requests.

## Required GitHub Actions configuration

Repository variables:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Repository secrets:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

The app build maps the two public Supabase values to `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` during static export.

Runtime application secrets such as Supabase privileged credentials and Resend keys remain server-side and must never be committed or exposed to the browser bundle.

## First production checkpoint

Run `Deploy Cloudflare` manually on `main` only after CI passes. The workflow must:

1. validate required public runtime variables and Cloudflare credentials;
2. build the static Next.js app into `out/`;
3. deploy `out/` to the Cloudflare Pages project `rembayung-access`;
4. deploy the broadcast Worker separately.

After deployment, smoke-test sign-up/sign-in, published sessions, join interest, and cancel interest against the production Supabase project.
