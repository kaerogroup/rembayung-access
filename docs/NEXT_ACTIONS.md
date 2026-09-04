# NEXT ACTIONS

## Active checkpoint — Slice B runtime acceptance

1. Join the fixed production Slice B test session as an authenticated user before the interest window closes.
2. Confirm the production checkpoint reports one active interest.
3. Allow the Cloudflare Cron scheduler to reach the due wave.
4. Verify the wave transitions `scheduled -> processing -> completed`.
5. Verify exactly one eligible interest becomes `selected` for `wave_size = 1`.
6. Verify exactly one invitation is created and the wave records `selected_count = 1`.
7. Re-run the runtime checkpoint to confirm idempotent state and no duplicate entitlement.
8. Record Slice B runtime acceptance in project state.

## After Slice B acceptance

1. Slice C — connect Resend delivery to pending invitation email deliveries.
2. Slice D — authenticated invitation gate, expiry/ownership validation and audited UMAI redirect.
3. Prove the end-to-end golden path.
4. Run larger fairness/idempotency acceptance with 100+ dummy interests.
5. Slice E — minimum admin surface for session configuration and operational observation.

## Guardrails

- No UMAI replacement in MVP.
- No payment, QR/device binding or advanced anti-fraud yet.
- No large re-audit before each slice; use focused CI, migration and runtime checkpoints.
