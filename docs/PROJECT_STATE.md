# PROJECT STATE

Last updated: 2026-09-05

## Current status

Rembayung Access is a production-connected mobile-first PWA for fair access before UMAI.

The core MVP authority chain is now accepted through minimum operations:

`Auth -> Interest -> Scheduled Wave -> Capacity-aware Fair Selection -> Invitation -> Resend Delivery -> Authenticated Rembayung Gate -> Audited UMAI Continuation`

Slices A–D are complete at their accepted boundaries. Capacity-aware allocation and Slice E minimum admin are also COMPLETE / production runtime accepted.

The active product checkpoint is no longer architecture expansion. It is operationalization of the first real Rembayung session plus real-user Resend sender-domain hardening.

## Completed / operational

- Canonical repository documentation and governed GitHub workflow.
- Mobile-first / PWA-first Next.js customer surface.
- Supabase Auth registration/login.
- Authenticated session listing and join/cancel interest commands.
- PostgreSQL authority for sessions, interests, draw waves, invitations, delivery outbox and redirect audits.
- Cloudflare every-minute scheduler and broadcast Worker.
- Idempotent wave materialization and server-only selection authority.
- Resend retryable invitation outbox with transient token clearing.
- Authenticated invitation open/redirect authority and redirect auditing.
- Full normal-flow production golden path accepted.
- Session-specific party-size constraints and allocation pax budget.
- Stable random priority that survives cancel/rejoin.
- Capacity-aware random-first selection with per-wave selected-pax accounting.
- Focused capacity acceptance and isolated 120-candidate mixed-party fairness/idempotency acceptance.
- Minimum admin membership/authority model.
- Mobile-first `/admin` surface for draft creation, publication and operational observation.
- Safe production bootstrap of the sole accepted operator as platform admin.
- Read-only Slice E production runtime checkpoint.

## Capacity-aware fair allocation — COMPLETE / production runtime accepted

Migration `20260905000800_capacity_aware_allocation.sql` established the production allocation model:
- `booking_sessions.min_party_size` / `max_party_size`;
- optional `allocation_capacity_pax`;
- stable `interests.selection_key`;
- `draw_waves.selected_pax`;
- `join_interest()` validates the selected session's policy;
- `process_due_wave()` serializes by session and only selects candidates whose party fits remaining access capacity.

Migration `20260905000900_capacity_runtime_acceptance.sql` verified party limits, stable priority, exact fit, over-capacity skip, pax accounting and repeat-processing idempotency in production.

Migration `20260905001000_capacity_load_fairness_acceptance.sql` then ran 120 mixed-party synthetic candidate references through the real `process_due_wave()` path without inserting fake `auth.users`. The transactional acceptance proved:
- stable priority, not FCFS, governs selection order;
- the selected set exactly matches the priority + capacity-fit contract;
- the pax budget is not exceeded;
- selected interests map one-to-one to invitation entitlement;
- rerunning the processor creates no additional entitlement.

This is access allocation only. UMAI continues to own actual table/time inventory, deposit/payment and confirmed reservation.

## Slice E minimum admin — COMPLETE / production runtime accepted

Migration `20260905001100_slice_e_minimum_admin.sql` added:
- `platform_admins` membership under RLS;
- service-role-only grant/revoke bootstrap functions;
- authenticated `is_platform_admin()`;
- authenticated admin RPCs `admin_create_session(...)`, `admin_publish_session(uuid)` and `admin_list_sessions()`;
- no direct authenticated write privilege to canonical booking/session tables.

The `/admin` static-export-safe PWA surface supports session configuration and operational counts while explicitly keeping winner authority in PostgreSQL.

Migration `20260905001200_slice_e_runtime_acceptance.sql` transactionally proved:
1. admin membership is recognized;
2. an admin can create a draft with party/capacity/wave/downstream configuration;
3. the operational projection returns the created configuration and zero-state counts correctly;
4. an admin can publish a valid future draft;
5. a non-admin authenticated identity is rejected;
6. acceptance fixture state is removed before completion.

Migration `20260905001300_bootstrap_single_operator_admin.sql` safely bootstraps an operator only when all uniqueness conditions are true. Its first production attempt exposed an unsupported `min(uuid)` aggregate and rolled back; the unapplied migration was corrected to ordered `LIMIT 1` identity lookup with explicit uniqueness counts.

The corrected production apply succeeded. A post-apply rerun of `Slice E Admin Runtime Checkpoint` confirmed:
- `auth_user_count = 1`;
- `platform_admin_count = 1`;
- `golden_path_user_count = 1`;
- `golden_path_user_is_admin = true`;
- the admin table and create/publish/list/check RPCs are present.

No user identifier or email is exposed by the checkpoint.

## Golden path reference

Accepted session:
`f0cc7c5e-5812-47c9-a405-aed71cb4eb73` — `[TEST] Golden Path — Invitation Gate`

Verified normal flow:
1. authenticated PWA join;
2. natural Cloudflare Cron draw;
3. exactly one selected interest and invitation;
4. exactly one Resend delivery with transient token cleared;
5. authenticated invitation open;
6. canonical UMAI destination resolved from PostgreSQL;
7. audited redirect;
8. no duplicate entitlement.

## Resend production-hardening boundary

Slice C remains prototype-runtime accepted, not real-user sender-domain accepted. Before real invitation delivery:
- verify a custom sending domain;
- remove `RESEND_TEST_RECIPIENT`;
- rotate the prototype key and prefer a domain-scoped sending-only key;
- configure the verified sender through governed deployment;
- run one real-domain delivery acceptance.

## Active next work — real session operationalization

1. Verify the deployed `/admin` operator experience in production.
2. Confirm the venue-authoritative real session parameters.
3. Create one real session as draft through admin authority.
4. Review its persisted configuration and operational projection.
5. Publish only after the schedule, capacity and UMAI destination are confirmed.
6. Verify scheduled wave materialization before public opening.
7. Harden Resend custom-domain delivery before real invitation waves.
8. Observe the first real interest pool with the existing admin projection and focused runtime checkpoints.

Do not add payment, actual table allocation, predictive AI, aggressive overbooking or advanced anti-fraud before this operational checkpoint produces evidence.

## Later work

- Controlled multi-wave replenishment from expired/unused entitlement capacity.
- Standby/reallocation.
- Optional slot preference and flexible-slot demand shaping.
- Conversion analytics.
- Foreground Supabase Realtime projection; later Web Push for closed/background PWA.
- Data-driven recommendations only after sufficient real-session evidence.

## Source of truth

`origin/main + Supabase migrations/schema + canonical docs + verified production runtime`

## Delivery posture

Use focused branch/PR changes, CI/dry-run gates, governed production apply/deploy and runtime acceptance. Do not repeat broad audits when authoritative checkpoints are green.

## Guardrails

- Rembayung Access controls fair access before UMAI; UMAI remains final reservation authority in MVP.
- Invitation is not a confirmed reservation.
- PostgreSQL remains winner authority.
- Admin configures/observes but never manually chooses winners.
- No payment integration yet.
- No QR/device binding yet.
- No advanced anti-fraud/risk scoring yet.
- PWA/offline state never becomes transactional authority.
