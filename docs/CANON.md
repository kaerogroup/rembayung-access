# CANON — Rembayung Access v0.1

## Product doctrine

### C-01 Fair access before reservation
Rembayung Access controls **who receives an opportunity to book**. UMAI remains the reservation authority in MVP.

### C-02 Random first, not fastest first
An eligible participant's chance must not depend on refresh speed, connection speed or button-click timing.

### C-03 Register once, activate interest many times
Identity is durable. Interest is session-specific and explicitly activated by the user.

### C-04 Predictable scheduled release
Draw/broadcast windows are public and understandable. Users know when waves begin and approximately when the release window ends.

### C-05 Automated waves
After configuration, wave release is automatic. Admin intervention is for exceptions, not normal operation.

### C-06 Invitation is not a reservation
An invitation grants access to continue toward UMAI; it does not claim that a table has been booked.

### C-07 No direct UMAI link in email
Email returns the user to Rembayung Access. The system validates invitation ownership and validity before redirect.

### C-08 Database authority
Selection, invitation lifecycle and audit data are decided and persisted server-side in PostgreSQL.

### C-09 Idempotent operations
Scheduler retries, network retries and email retries must not create duplicate waves or duplicate invitation entitlement.

### C-10 Minimum friction
Normal users should see only: upcoming session, join interest, waiting status, invitation, continue to UMAI.

### C-11 Progressive hardening
Device binding, dynamic QR, payments and stronger anti-transfer controls are future slices, not MVP blockers.

### C-12 Replace UMAI only by evidence
UMAI retirement is a later architecture decision after the access-layer model proves useful in runtime.

### C-13 Mobile first
Primary customer journeys are designed and acceptance-tested for mobile viewport, touch interaction and one-handed use before desktop enhancement. Desktop is a progressive enhancement, not the baseline.

### C-14 PWA first
The customer surface must be installable as a Progressive Web App with a valid web app manifest, app icons, standalone display mode and service-worker lifecycle. The architecture must not require an app-store binary for the core journey.

### C-15 Resilient network behaviour
Poor or interrupted connectivity must fail safely. Static shell/assets may be cached for fast repeat launch, but transactional state such as interest status, draw outcome and invitation validity must always reconcile with Supabase authority before being presented as current.

### C-16 PWA is not offline authority
Offline capability must never fabricate or locally finalize booking, invitation, draw or reservation state. Writes are acknowledged only after server confirmation. Any queued/retry behaviour must be explicit and idempotent.
