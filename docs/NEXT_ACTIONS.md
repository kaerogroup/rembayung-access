# NEXT ACTIONS

## Completed checkpoint — end-to-end golden path

The full production-connected golden path is now accepted. Do not rebuild the existing draw, delivery outbox or invitation authority.

Verified path:

1. authenticated user joined `[TEST] Golden Path — Invitation Gate` through the normal PWA flow;
2. natural Cloudflare Cron processed the scheduled wave without a manual draw;
3. Wave 1 completed with `selected_count = 1` and no error;
4. the interest transitioned `active -> selected` exactly once;
5. exactly one invitation and one delivery were created;
6. Resend prototype transport sent exactly one test message with `attempt_count = 1`;
7. the transient invitation token was cleared after successful delivery;
8. the authenticated owner opened `/invitation?token=...`;
9. PostgreSQL revalidated the redirect boundary and returned only the canonical configured downstream destination;
10. the invitation reached `redirected` and exactly one `redirect_audits` row was recorded;
11. no second entitlement was created.

## Active focus — capacity-aware fair allocation

The next implementation should improve allocation quality without changing the product boundary: Rembayung Access controls fair access; UMAI remains final booking/table/deposit authority.

Focused implementation order:

1. Add session-specific `min_party_size` and `max_party_size` with safe defaults compatible with existing sessions.
2. Update `join_interest()` to validate against the selected session's limits rather than a global 2–8 assumption.
3. Configure real Rembayung venue sessions for 3–8 pax; children/babies counting toward pax remains venue policy/informational context, not identity authority.
4. Add a session allocation capacity/budget in pax, separate from UMAI's final table inventory.
5. Evolve random-first selection into capacity-aware random allocation: random priority remains the fairness mechanism, but a candidate is selected only when its party size fits the remaining allocation budget.
6. Keep browser and admin surfaces out of winner authority; PostgreSQL remains selection authority.
7. Preserve idempotency: reruns must not create duplicate invitations or exceed the allocation budget.
8. Add focused SQL verification for mixed party sizes, exact-fit, residual capacity smaller than remaining parties, zero eligible interests and repeated processing.
9. Run a larger fairness/idempotency acceptance with 100+ dummy interests only after the capacity rules pass focused verification.
10. After capacity acceptance, proceed to Slice E minimum admin for session configuration and operational observation.

Do not introduce predictive AI, aggressive overbooking, advanced anti-fraud, payment or table-layout logic in this slice. Those need runtime data and are not required to solve the current scarce-capacity allocation problem.

## Production hardening still pending separately

Before real-user email launch:
- verify a custom sending domain;
- remove `RESEND_TEST_RECIPIENT`;
- rotate the prototype API key and prefer a domain-scoped sending-only key;
- perform one real-domain delivery acceptance.

## Later optimization path

After capacity-aware allocation is stable and measurable:
- controlled multi-wave replenishment based on unused/expired entitlement capacity;
- standby/reallocation for expired invitations;
- optional slot preference and flexible-slot demand shaping;
- conversion analytics from selection -> open -> downstream continuation;
- only then consider data-driven wave-size recommendations or controlled oversubscription.

## Guardrails

- No UMAI replacement in MVP.
- Invitation is access entitlement, not a confirmed reservation.
- Invitation email returns to Rembayung Access, not directly to UMAI.
- Never log recipient email addresses or plaintext invitation tokens in operational diagnostics.
- Browser state is never invitation/redirect/winner authority.
- No payment, QR/device binding or advanced anti-fraud yet.
- No large re-audit before each slice; use focused CI, migration and runtime checkpoints.
