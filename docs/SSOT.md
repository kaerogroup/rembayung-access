# REMBAYUNG ACCESS — SSOT v0.1

Status: PROTOTYPE / MVP

## 1. Product definition

Rembayung Access is a fair-access layer placed **before UMAI**. It does not replace UMAI in v0.1.

Canonical customer flow:

`Register once -> Join interest -> Scheduled random wave -> Invitation -> Open invitation in system -> Continue to UMAI`

## 2. Problem

Current high-demand booking behaves like a battle booking: many users compete at the same release time. This creates traffic spikes and rewards speed, automation and repeated attempts.

The MVP changes allocation from speed-based access to scheduled random access.

## 3. MVP boundary

### In scope
- One-time account registration/login.
- Upcoming booking sessions.
- Join/cancel interest before pool closes.
- Party size 2-8.
- Scheduled draw start.
- Automatic broadcast waves.
- Random-first selection.
- Time-limited invitation.
- Email via Resend.
- Invitation page inside our system.
- Authenticated redirect to UMAI.
- Audit trail for draw, invitation, email and redirect.
- Minimum admin operations.

### Out of scope
- Replacing UMAI reservation/table/floor/menu functions.
- Taking deposit/payment.
- Dynamic QR check-in.
- Device binding.
- POS/menu integration.
- AI.
- Advanced anti-fraud/risk scoring.
- Guaranteed seat allocation after redirect to UMAI.

## 4. Authority boundaries

| Concern | Authority in v0.1 |
|---|---|
| Identity | Supabase Auth |
| Interest | Our PostgreSQL database |
| Draw / wave selection | Our PostgreSQL database |
| Invitation eligibility | Our PostgreSQL database |
| Email delivery | Resend |
| Web/UI/API | Cloudflare Workers |
| Final booking | UMAI |
| Table/floor/menu | UMAI |

## 5. Canonical states

### Interest
`active -> selected | cancelled | closed`

### Invitation
`issued -> opened -> redirected`

Terminal alternatives:
`issued/opened -> expired | revoked`

### Wave
`scheduled -> processing -> completed | failed`

### Email delivery
`pending -> sending -> sent | failed`

## 6. Core rules

1. A user registers once.
2. A user can join many future sessions, but only once per session.
3. Party size is required and constrained to 2-8.
4. Interest cannot be newly joined after `interest_closes_at`.
5. Draw begins at `draw_starts_at`.
6. Waves release automatically using random-first selection.
7. Browser/client never decides winners.
8. An invitation is not a reservation.
9. Invitation email returns the user to Rembayung Access, not directly to UMAI.
10. The system validates invitation ownership and expiry before redirect.
11. UMAI remains final reservation authority in MVP.
12. Service-role credentials and Resend API keys are server/worker only.
13. UMAI destination is configuration, not hard-coded UI state.
14. Draw, invitation, delivery and redirect activity must be auditable.
15. Scheduler and email operations must be idempotent.

## 7. Prototype success criteria

MVP is accepted when we can demonstrate end-to-end:

1. 100+ dummy users/interests exist.
2. A scheduled wave runs without admin action.
3. Random users are selected exactly once.
4. Invitation rows are created.
5. Resend sends invitation email.
6. Selected user opens a unique system invitation URL.
7. Wrong user cannot use that invitation.
8. Valid user can continue to UMAI.
9. Redirect is recorded.
10. Re-running the scheduler does not duplicate the same wave/invitations.

## 8. Delivery source of truth

`origin/main + Supabase migrations + canonical docs + verified production runtime`

## 9. Golden path

`ChatGPT -> feature branch/PR -> GitHub Actions -> Cloudflare preview -> runtime check -> merge main -> Cloudflare production -> smoke verification -> project-state update`

No large re-audit before every slice. Use focused migration, CI and runtime checkpoints.
