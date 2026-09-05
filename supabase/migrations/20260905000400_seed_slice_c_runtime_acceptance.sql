-- Slice C runtime acceptance session.
-- Purpose: verify draw -> retryable outbox -> Resend delivery end-to-end.
-- Prototype sender uses onboarding@resend.dev; UMAI remains non-routable.

insert into public.booking_sessions (
  id,
  title,
  starts_at,
  interest_opens_at,
  interest_closes_at,
  draw_starts_at,
  wave_size,
  wave_interval_minutes,
  max_waves,
  invitation_ttl_minutes,
  umai_url,
  status
)
values (
  '9e7e5bf7-2f4b-4e50-a7b1-dc28c1dfe3a7'::uuid,
  '[TEST] Slice C — Resend Delivery Runtime',
  '2026-09-05 19:00:00+08'::timestamptz,
  '2026-09-05 09:00:00+08'::timestamptz,
  '2026-09-05 09:20:00+08'::timestamptz,
  '2026-09-05 09:22:00+08'::timestamptz,
  1,
  5,
  1,
  30,
  'https://example.invalid/umai-slice-c-runtime-test',
  'published'::public.session_status
)
on conflict (id) do update set
  title = excluded.title,
  starts_at = excluded.starts_at,
  interest_opens_at = excluded.interest_opens_at,
  interest_closes_at = excluded.interest_closes_at,
  draw_starts_at = excluded.draw_starts_at,
  wave_size = excluded.wave_size,
  wave_interval_minutes = excluded.wave_interval_minutes,
  max_waves = excluded.max_waves,
  invitation_ttl_minutes = excluded.invitation_ttl_minutes,
  umai_url = excluded.umai_url,
  status = excluded.status;
