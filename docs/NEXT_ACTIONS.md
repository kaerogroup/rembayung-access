# NEXT ACTIONS

## Active checkpoint — Slice C production email acceptance

Slice C delivery implementation is already merged, migrated and deployed. Do not rebuild the delivery architecture.

1. Configure the GitHub `production` environment with all three required values:
   - `RESEND_API_KEY`
   - `RESEND_FROM_EMAIL`
   - `APP_BASE_URL`
2. Run the governed Cloudflare Broadcast Worker deployment and confirm it selects the `with Resend` path.
3. Create a fresh bounded production acceptance invitation through the existing draw authority; do not reconstruct or reuse the pre-Slice-C invitation token.
4. Verify the outbox transitions `pending -> sending -> sent`.
5. Verify exactly one Resend provider message ID is recorded and `attempt_count` remains bounded.
6. Verify the transient outbox invitation token is cleared after `sent`.
7. Re-run the Slice C runtime checkpoint and confirm no duplicate send or stuck `sending` row.
8. Record Slice C production acceptance in project state.

## Implemented Slice C foundation

- database-backed retryable invitation email outbox;
- transient token persistence only while delivery remains actionable;
- service-role-only claim, complete, fail and expire RPCs;
- retry backoff and stale-send reclaim;
- Resend transport in the Cloudflare Broadcast Worker;
- stable per-invitation Resend idempotency key;
- invitation email returns to Rembayung Access rather than UMAI;
- read-only production delivery checkpoint;
- governed Worker deploy supports both Resend-enabled and safe inactive modes.

Current production evidence shows the Worker Cron is healthy but Resend delivery is inactive because production configuration is incomplete.

## After Slice C

1. Slice D — authenticated invitation gate, expiry/ownership validation and audited UMAI redirect.
2. Prove the complete end-to-end golden path.
3. Run larger fairness/idempotency acceptance with 100+ dummy interests.
4. Slice E — minimum admin surface for session configuration and operational observation.

## Completed checkpoint — Slice B

- production Cloudflare Cron verified firing;
- Wave 1 completed with one selection and one invitation;
- Wave 2 completed with zero further selections;
- invitation total remained one;
- no duplicate entitlement;
- production pgcrypto schema-resolution defect corrected through migration `20260905000200_fix_slice_b_pgcrypto_schema.sql`.

## Guardrails

- No UMAI replacement in MVP.
- Invitation email returns to Rembayung Access, not directly to UMAI.
- Never log recipient email addresses or plaintext invitation tokens in operational diagnostics.
- No payment, QR/device binding or advanced anti-fraud yet.
- No large re-audit before each slice; use focused CI, migration and runtime checkpoints.
