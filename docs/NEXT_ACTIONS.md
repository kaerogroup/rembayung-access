# NEXT ACTIONS

## Active slice — Slice C Resend invitation delivery

1. Consume pending `email_deliveries` created by successful draw selection.
2. Send the transactional invitation email through Resend from server/Worker runtime only.
3. Construct the invitation URL back into Rembayung Access; never email the UMAI URL directly.
4. Record delivery provider result, provider message ID, attempt count, sent timestamp and bounded failure information.
5. Make delivery retry-safe and idempotent so scheduler/network retries do not duplicate entitlement or uncontrolled email sends.
6. Verify production delivery against the existing invitation/outbox authority.
7. Keep the notification architecture extensible for Supabase Realtime in-app updates and future Web Push; notification channels remain signals, never transactional authority.

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
- No payment, QR/device binding or advanced anti-fraud yet.
- No large re-audit before each slice; use focused CI, migration and runtime checkpoints.
