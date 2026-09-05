# STATUS

Last updated: 2026-09-05

Slice A is implemented and production-connected.
Slice B scheduled random draw is COMPLETE — production runtime accepted.
Slice C Resend invitation delivery is COMPLETE for prototype acceptance — production Worker transport, retry/outbox state and token clearing were runtime verified.
Slice D authenticated invitation gate is COMPLETE — core authority and full human-visible golden-path production acceptance are verified.
Capacity-aware fair allocation is COMPLETE — focused and 120-candidate production acceptance are verified.
Slice E minimum admin is COMPLETE — authority, operational projection, admin bootstrap and production runtime checkpoint are verified.

## Golden path

The normal production-connected flow is accepted:

`authenticated join -> natural Cron draw -> invitation -> Resend delivery -> authenticated Rembayung gate -> audited UMAI continuation`

The accepted golden-path session produced exactly one entitlement, one delivery and one redirect audit without a manual draw or duplicate invitation.

## Capacity-aware fair allocation — COMPLETE

Migration `20260905000800_capacity_aware_allocation.sql` introduced:
- session-specific `min_party_size` and `max_party_size`;
- optional `allocation_capacity_pax` separate from UMAI table inventory;
- stable per-interest `selection_key` random priority;
- `draw_waves.selected_pax` observability;
- session-serialized capacity-aware `process_due_wave()` selection;
- dynamic party-size choices in the PWA.

Production acceptance migration `20260905000900_capacity_runtime_acceptance.sql` proved:
- session-specific party-size enforcement;
- cancel/rejoin does not reroll stable priority;
- exact-fit pax allocation works;
- a valid party that cannot fit remaining capacity is skipped;
- selected-pax accounting is correct;
- repeated processing does not create duplicate entitlement.

Load/fairness migration `20260905001000_capacity_load_fairness_acceptance.sql` then exercised the real allocation path with 120 mixed-party synthetic candidate references, without inserting fake Auth users. It proved:
- selection follows stable random priority rather than first-come-first-served order;
- the selected set exactly matches the priority + capacity-fit contract;
- pax budget is respected;
- one invitation is created per selected interest;
- repeated processing is idempotent.

This remains access-capacity allocation only. UMAI is still final authority for real date/time/table availability, deposit, payment and reservation confirmation.

## Slice E minimum admin — COMPLETE

Migration `20260905001100_slice_e_minimum_admin.sql` added:
- `platform_admins` membership with RLS;
- service-role-only admin grant/revoke bootstrap authority;
- authenticated `is_platform_admin()`;
- `admin_create_session(...)` for draft session configuration;
- `admin_publish_session(uuid)` for controlled publication;
- `admin_list_sessions()` for pool/wave/invitation/delivery operational projection;
- no authenticated direct-write authority to canonical booking tables.

The mobile-first `/admin` PWA surface now supports:
- session title/timeline configuration;
- min/max party size;
- allocation pax budget;
- wave size, interval and maximum waves;
- invitation TTL;
- downstream UMAI URL;
- draft creation and publication;
- operational counts for interests, waves, invitations and email delivery.

Production acceptance migration `20260905001200_slice_e_runtime_acceptance.sql` proved admin membership, create, observe, publish, non-admin rejection and cleanup boundaries.

Operational bootstrap migration `20260905001300_bootstrap_single_operator_admin.sql` was then applied after a UUID-aggregate compatibility fix. The post-apply runtime checkpoint confirmed:
- exactly one current Auth identity;
- exactly one platform admin;
- the accepted golden-path operator is that admin;
- all Slice E admin table/RPC objects are present.

Therefore the current accepted operator can use `/admin` without browser self-elevation or exposing identity details.

## Resend prototype status

Prototype delivery is accepted, but real-user email hardening remains deliberately separate. Before real-user launch:
- verify a custom sending domain;
- remove `RESEND_TEST_RECIPIENT`;
- rotate the prototype Resend API key and prefer a domain-scoped sending-only key;
- perform one real-domain delivery acceptance.

## Active next focus

Operationalize a real Rembayung session through the accepted admin surface rather than adding more allocation architecture:
- verify the production `/admin` route and authenticated operator experience;
- enter one real session configuration with the venue-approved party-size range, pax allocation budget, release timing, wave settings and UMAI destination;
- review the draft before publication;
- publish only when the venue schedule/configuration is authoritative;
- observe the first real pool through existing read-only operational projections;
- harden Resend custom-domain delivery before invitations are sent to real users.

Do not broaden into payments, table allocation, predictive AI, advanced anti-fraud or UMAI replacement at this checkpoint.
