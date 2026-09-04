# Branch Policy

- `main` is the production source branch.
- Product changes are developed on short-lived feature branches.
- Pull requests must pass GitHub Actions before merge.
- Cloudflare preview is checked before merge when preview deployment is available.
- Production deployment follows merge to `main` after the deployment workflow is enabled.
