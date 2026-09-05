# NEXT ACTIONS

## Active checkpoint — Slice D invitation gate

Slice C prototype delivery acceptance is complete. Do not rebuild the draw or delivery architecture.

Build the authenticated invitation gate as the next focused slice:

1. Add the Rembayung invitation route for a token received from the invitation email.
2. Resolve the token server-side against the stored invitation token hash; never expose hash authority to the browser.
3. Require authenticated ownership: the current Supabase identity must match the invitation owner.
4. Reject expired, revoked or otherwise non-actionable invitations.
5. Mark a valid invitation `opened` through server authority when appropriate and idempotently.
6. Present a clear confirmation surface explaining that the invitation is access to continue, not a completed reservation.
7. Continue to the configured UMAI destination only through a server-validated action.
8. Record the redirect in `redirect_audits` before/with the outbound UMAI redirect.
9. Runtime-test valid owner, wrong owner, expired token and repeated-open/redirect behavior.
10. Prove the complete golden path: join -> scheduled draw -> invitation -> delivery -> open in Rembayung -> validated UMAI redirect.

## Completed checkpoint — Slice C prototype delivery

- production Worker deployed with Resend transport enabled;
- fresh invitation created through the existing natural Cron draw path;
- database-backed outbox and bounded retry behavior verified;
- Resend test-sender restriction was handled by a prototype-only transport override to `delivered@resend.dev`;
- authoritative recipient data remained unchanged in the outbox;
- exactly one test email was accepted/delivered by Resend;
- final delivery state is `sent`;
- transient invitation token was cleared after send;
- no stuck `pending`/`sending` row and no retained plaintext token remain.

Before real-user email production launch:
- verify a custom sending domain;
- remove `RESEND_TEST_RECIPIENT`;
- rotate the prototype API key and prefer a domain-scoped sending-only key;
- perform one real-domain delivery acceptance without changing invitation authority.

## After Slice D

1. Run larger fairness/idempotency acceptance with 100+ dummy interests.
2. Slice E — minimum admin surface for session configuration and operational observation.
3. Add foreground Supabase Realtime projections and later Web Push without changing PostgreSQL authority.

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
- Browser state is never invitation/redirect authority.
- No payment, QR/device binding or advanced anti-fraud yet.
- No large re-audit before each slice; use focused CI, migration and runtime checkpoints.
