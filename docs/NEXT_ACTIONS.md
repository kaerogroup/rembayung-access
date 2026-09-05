# NEXT ACTIONS

## Active checkpoint — complete golden-path acceptance

Slice D core invitation authority is implemented, production-applied and verified. Do not rebuild the invitation RPCs, draw architecture or delivery outbox.

Next focused checkpoint:

1. Create a fresh bounded acceptance session using the existing session/draw authority.
2. Join through the normal authenticated PWA flow.
3. Let natural Cloudflare Cron perform the scheduled random draw; do not invoke the draw manually.
4. Verify exactly one invitation and retryable delivery row are created.
5. Let the existing Resend prototype transport deliver the invitation test message exactly once.
6. Open the new `/invitation?token=...` Rembayung route from the generated invitation link.
7. Verify the intended authenticated owner sees the session details and actionable invitation state.
8. Verify the redirect action is revalidated by PostgreSQL and returns only the configured UMAI destination.
9. Verify `redirect_audits` records the action and the invitation reaches `redirected` without creating a second entitlement.
10. Record the end-to-end golden path in project state.

If direct browser access to Cloudflare Pages remains unavailable through connected tooling, do not weaken the authority checks. Use available runtime evidence and leave only the human-visible page interaction as an explicit founder acceptance checkpoint.

## Completed checkpoint — Slice D core invitation authority

- `/invitation?token=...` static PWA route implemented;
- authenticated `open_invitation(text)` resolves only token + owner matches;
- expired/revoked state is enforced by PostgreSQL;
- valid `issued` invitation becomes `opened` idempotently;
- authenticated `redirect_invitation(text,text)` revalidates before returning a destination;
- UMAI destination comes from canonical `booking_sessions.umai_url`;
- redirect actions are inserted into `redirect_audits`;
- repeated redirect returns the same destination without creating another entitlement;
- production verification migration `20260905000600_slice_d_runtime_acceptance.sql` PASS for valid owner, wrong owner, repeat redirect and expiry behavior;
- temporary acceptance fixture was cleaned before migration commit;
- invitation page typecheck/build/static PWA output PASS.

The first attempted runtime harness using `supabase db query --linked` was retired because that Management API query path is read-only in this environment. The governed verification migration is the accepted runtime evidence path for write assertions.

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

## After golden-path acceptance

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
