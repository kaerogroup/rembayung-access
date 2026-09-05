# PROJECT STATE

Last updated: 2026-09-05

## Current status

Rembayung Access is a production-connected MVP for fair access before UMAI.

Slice A is implemented. Slice B scheduled random draw is COMPLETE — production runtime accepted. Slice C Resend invitation delivery is COMPLETE for prototype runtime acceptance. Slice D authenticated invitation gate is COMPLETE for core production authority acceptance.

The active checkpoint is now the complete end-to-end golden path: authenticated join -> natural scheduled draw -> invitation delivery -> open inside Rembayung -> authenticated validation -> audited UMAI redirect boundary.

## Completed / operational

- Repository identity and canonical documentation: README, SSOT, Canon, ERD, Flows and Architecture.
- Mobile-first / PWA-first Next.js customer surface.
- Supabase Auth registration/login.
- Published session listing.
- Authenticated join/cancel interest RPCs with server-side eligibility checks.
- PostgreSQL authority for sessions, interests, draw waves, invitations, email delivery outbox and redirect audits.
- Idempotent draw-wave materialization via `ensure_draw_waves()`.
- Server-only random-first selection via `process_due_wave()`.
- Cloudflare broadcast Worker deployed with every-minute Cron trigger.
- GitHub Actions CI on pull requests and `main`.
- Supabase migration dry-run gate on PRs and governed migration apply on `main`.
- Governed Cloudflare broadcast Worker deployment from `main`.
- Read-only Slice B and Slice C production runtime checkpoints through GitHub Actions.
- Cloudflare Cron and Worker runtime-tail diagnostics for focused operational debugging.
- Retryable Slice C invitation email outbox and Resend Worker transport deployed and prototype-accepted.
- Static-export-safe Slice D invitation surface at `/invitation?token=...`.
- Authenticated PostgreSQL invitation open and redirect authority with redirect auditing.

## Slice B — COMPLETE / production runtime accepted

Fixed acceptance session:

`4e690585-4986-48d9-a6cb-1a0d168fd06f` — `[TEST] Slice B — Random Draw Runtime`

Verified production evidence:

1. authenticated user joined one interest;
2. Cloudflare Cron invocation executed without admin-triggered draw execution;
3. Wave 1 completed at 2026-09-05 07:51:45 MYT with `selected_count = 1`;
4. the sole eligible interest transitioned `active -> selected` exactly once;
5. exactly one invitation was created;
6. Wave 2 completed at 2026-09-05 07:52:45 MYT with `selected_count = 0`;
7. invitation total remained exactly one after Wave 2;
8. both completed waves recorded no error.

Focused acceptance diagnostics also corrected the Supabase secret-key auth boundary and schema-qualified Supabase `pgcrypto` routines under `extensions` through migration `20260905000200_fix_slice_b_pgcrypto_schema.sql`.

No manual draw RPC was used for final acceptance.

## Slice C — COMPLETE / prototype runtime accepted

Authority and delivery behavior:

- migration `20260905000300_slice_c_resend_delivery_outbox.sql` adds retryable outbox state;
- invitation plaintext token is retained only in the RLS-protected delivery row while delivery is actionable and is cleared after successful send or expiry;
- pre-Slice-C rows without reconstructable plaintext are explicitly retired;
- `claim_pending_email_delivery()` uses row locking, bounded retry eligibility and stale-send reclaim;
- `complete_email_delivery()` records provider completion and clears the transient token;
- `fail_email_delivery()` records errors and schedules bounded retry backoff;
- `expire_email_deliveries()` retires expired unsent payloads;
- delivery mutation RPCs are service-role-only;
- Broadcast Worker drains a bounded number of deliveries per Cron tick;
- Resend uses a stable per-invitation idempotency key;
- operational logs do not expose recipient emails or plaintext invitation tokens;
- invitation email points back to Rembayung Access rather than UMAI.

Prototype acceptance session:

`9e7e5bf7-2f4b-4e50-a7b1-dc28c1dfe3a7` — `[TEST] Slice C — Resend Delivery Runtime`

Verified production evidence:

1. authenticated interest entered the test session through the existing customer PWA flow;
2. natural Cloudflare Cron selected the interest and created exactly one invitation/outbox delivery;
3. initial Resend attempts were rejected because `onboarding@resend.dev` cannot send to arbitrary real recipients;
4. prototype-only `RESEND_TEST_RECIPIENT=delivered@resend.dev` was introduced while leaving the authoritative recipient unchanged in PostgreSQL;
5. the same retryable delivery was claimed again by natural Cron and Resend accepted exactly one test email;
6. Resend recorded the test message as `delivered` at 2026-09-05 09:44:43 MYT;
7. the outbox row transitioned to `sent` at 2026-09-05 09:44:43 MYT with `attempt_count = 5` and `last_error = null`;
8. `invitation_token` was cleared after completion;
9. runtime checkpoint at 2026-09-05 09:45:48 MYT reported `rows_retaining_token = 0`, `pending = 0`, `sending = 0` and one sent Slice C delivery;
10. the only other failed delivery is the intentionally retired pre-Slice-C legacy row with no retained plaintext token.

This closes prototype delivery acceptance, not real-user sender-domain hardening. Before production email to real users:

- verify a custom sending domain;
- remove the `RESEND_TEST_RECIPIENT` prototype override;
- rotate the prototype Resend API key and prefer a domain-scoped sending-only key;
- perform one real-domain delivery acceptance.

## Slice D — COMPLETE / core production authority accepted

Implementation:

- migration `20260905000500_slice_d_invitation_gate.sql` adds the authenticated invitation authority;
- `/invitation?token=...` is a static-export-safe PWA route so Cloudflare Pages can serve it without moving transactional authority into static client code;
- `open_invitation(text)` hashes the supplied token inside PostgreSQL and resolves only an invitation owned by `auth.uid()`;
- expired invitations are transitioned to `expired`; revoked invitations remain non-actionable;
- a valid `issued` invitation transitions idempotently to `opened` and retains its original ownership/entitlement;
- `redirect_invitation(text,text)` revalidates token, owner and expiry before reading the canonical `booking_sessions.umai_url`;
- the browser never chooses or supplies the UMAI destination;
- a valid redirect transitions the invitation to `redirected` and inserts `redirect_audits`;
- the optional browser-computed user-agent hash is audit metadata only and is not an authorization factor;
- new invitation emails generated by the broadcast Worker now link to the Rembayung invitation gate rather than a dynamic path or direct UMAI URL.

Production evidence:

1. PR #38 passed migration dry-run, foundation checks, typecheck, build and static PWA output;
2. migration `20260905000500_slice_d_invitation_gate.sql` applied to production successfully;
3. the Broadcast Worker with the new `/invitation?token=...` link deployed successfully;
4. an initial write-based runtime workflow was correctly retired after `supabase db query --linked` proved read-only through the Management API in this environment; that failure occurred before any Slice D RPC was exercised and was a harness limitation, not a product failure;
5. verification migration `20260905000600_slice_d_runtime_acceptance.sql` then executed the real production invitation RPCs through the governed migration path;
6. production migration apply PASS proves its assertions all succeeded: valid owner opened the invitation, wrong owner resolved zero rows, first redirect returned the canonical destination and created one audit, repeat redirect returned the same destination without creating another entitlement and created a second audit, and expiry blocked any further redirect/audit;
7. the verification migration removed its temporary fixture rows before commit.

The invitation page itself passed typecheck, build and static-export verification. Direct independent inspection of the Cloudflare Pages URL was not available through the current connected tooling, so human-visible page interaction is intentionally carried into the golden-path acceptance checkpoint rather than being claimed as independently runtime-verified.

For MVP Slice D, the authenticated Supabase RPC boundary is the server-side validation authority. The static browser surface only presents the token and authenticated session, displays the authoritative result, and navigates to a destination returned by PostgreSQL.

## Active checkpoint — complete golden path

Prove one fresh path end to end without manually invoking the draw:

1. authenticated join;
2. natural Cloudflare scheduled wave;
3. exactly one invitation/outbox entitlement;
4. Resend prototype delivery exactly once;
5. open the generated `/invitation?token=...` route;
6. owner sees the authoritative invitation details;
7. redirect action is revalidated by PostgreSQL;
8. invitation becomes `redirected` and `redirect_audits` records the action;
9. no duplicate invitation/entitlement is created.

## Subsequent work

### Scale acceptance
- run larger fairness/idempotency acceptance with 100+ dummy interests.

### Slice E — Minimum admin
- create/publish sessions;
- configure draw/wave parameters and UMAI destination;
- observe pool, wave, invitation and delivery state.

### Notification projection
- foreground Supabase Realtime first;
- later Web Push for closed/background PWA;
- PostgreSQL remains transactional authority.

## Source of truth

`origin/main + Supabase migrations + canonical docs + verified production runtime`

## Delivery posture

Use focused branch/PR changes, CI/dry-run gates, governed production apply/deploy and runtime acceptance. Do not repeat broad audits when authoritative checkpoints are already green.

## Guardrails

- Rembayung Access controls fair access before UMAI; UMAI remains final reservation authority in MVP.
- No payment integration yet.
- No QR/device binding yet.
- No advanced anti-fraud/risk scoring yet.
- PWA/offline state never becomes transactional authority.
