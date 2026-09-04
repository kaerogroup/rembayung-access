# CI/CD

## Golden path

`ChatGPT -> feature branch -> pull request -> GitHub Actions -> Cloudflare preview -> runtime acceptance -> merge main -> Cloudflare production -> smoke verification`

## Current bootstrap state

- CI on pull requests and pushes to `main`.
- Cloudflare deploy workflow is manual until account credentials and first runtime deployment are verified.
- After the first deployment passes, production deployment can be enabled on push to `main` and preview deployment on pull requests.

## Required GitHub secrets for Cloudflare deployment

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

Runtime application secrets such as Supabase service credentials and Resend keys remain server-side and must never be committed.
