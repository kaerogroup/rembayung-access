# NEXT ACTIONS

## Completed checkpoint — fair-access core through minimum admin

Do not rebuild the accepted draw, delivery, invitation, capacity or admin authority.

Production-accepted capabilities now include:
1. authenticated join/cancel interest;
2. scheduled Cloudflare Cron wave processing;
3. stable random-first priority;
4. session-specific party-size policy;
5. pax-budget-aware selection with idempotent invitation issuance;
6. retryable Resend delivery outbox;
7. authenticated invitation open and audited UMAI continuation;
8. 120-candidate mixed-party fairness/idempotency acceptance;
9. minimum admin create/publish/observe authority;
10. one safely bootstrapped production platform operator.

## Active focus — operationalize the first real Rembayung session

Use the accepted `/admin` surface and existing database authority. Do not add another architecture layer before this operational checkpoint.

Focused order:
1. Verify `/admin` is reachable in the current production PWA and the accepted operator resolves as platform admin.
2. Obtain/confirm the real venue session facts: title/date/time, interest open/close, draw start, party-size range, pax allocation budget, wave size/interval/count, invitation TTL and canonical UMAI destination.
3. Create the session as `draft` through the admin RPC/UI.
4. Review the persisted draft and operational projection before publication.
5. Publish only when schedule and downstream UMAI destination are authoritative.
6. Verify scheduler materializes the expected waves without any manual winner selection.
7. Observe pool/wave/invitation/delivery counts through `admin_list_sessions()`; browser remains observation/configuration only.
8. Run one focused production checkpoint for the real session configuration before public interest opens.

## Real-user email hardening — parallel prerequisite before invitations

Prototype Resend transport must not be treated as real-user-ready. Before a real invitation wave:
- verify a custom sending domain;
- configure the verified domain sender;
- remove `RESEND_TEST_RECIPIENT`;
- rotate the prototype API key and prefer a domain-scoped sending-only key;
- deploy through the governed GitHub -> Cloudflare path;
- perform one real-domain delivery acceptance and confirm transient token clearing/idempotency.

## Later optimization path

Only after real sessions produce evidence:
- controlled multi-wave replenishment from expired/unused entitlement capacity;
- standby/reallocation;
- optional slot preference and flexible-slot demand shaping;
- conversion analytics from selection -> open -> downstream continuation;
- foreground Realtime projection and later Web Push;
- data-driven wave recommendations only when enough production evidence exists.

## Guardrails

- Rembayung Access controls fair access before UMAI; UMAI remains final reservation authority.
- Invitation is an access entitlement, not a confirmed reservation.
- PostgreSQL remains winner and transactional authority.
- Admin can configure and observe; admin/browser cannot manually choose winners.
- Never log recipient email addresses or plaintext invitation tokens in operational diagnostics.
- PWA/offline state never becomes transactional authority.
- No payment, table-layout, QR/device binding or advanced anti-fraud in this checkpoint.
- No broad re-audit; use focused CI, migration and runtime evidence.
