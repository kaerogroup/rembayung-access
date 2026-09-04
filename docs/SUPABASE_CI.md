# Supabase CI Checkpoint

This repository treats `supabase/migrations/` as the schema source of truth.

## Required GitHub Actions configuration

Repository variable:

- `SUPABASE_PROJECT_REF`

Repository secrets:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_DB_PASSWORD`

## Dry-run policy

For migration changes, GitHub Actions must first run:

```bash
supabase link --project-ref "$SUPABASE_PROJECT_REF" --password "$SUPABASE_DB_PASSWORD"
supabase migration list --linked
supabase db push --linked --dry-run
```

A successful dry-run is a checkpoint only. It does not authorize or imply a production migration push.

Actual remote migration application remains a separate governed step after review.
