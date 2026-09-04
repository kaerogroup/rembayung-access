-- Runtime acceptance seed for Slice A.
-- This session is intentionally marked TEST and does not represent a real Rembayung reservation slot.
-- It exists only to verify authenticated join_interest -> cancel_interest end to end.

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
  '8e9fd728-4c21-4dde-ae7f-0d785135ea41'::uuid,
  '[TEST] Sesi Dinner — Runtime Acceptance',
  '2026-09-06 19:00:00+08'::timestamptz,
  '2026-09-04 00:00:00+08'::timestamptz,
  '2026-09-05 23:30:00+08'::timestamptz,
  '2026-09-06 00:00:00+08'::timestamptz,
  10,
  12,
  3,
  10,
  'https://example.invalid/umai-runtime-test',
  'published'
)
on conflict (id) do update
set
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
