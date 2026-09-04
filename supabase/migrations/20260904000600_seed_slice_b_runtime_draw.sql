-- Slice B runtime acceptance session.
-- Purpose: verify scheduled wave materialization + random selection end-to-end.
-- UMAI destination remains intentionally non-routable during acceptance.
-- Runtime window deliberately leaves enough time for governed deploy + user join.

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
  '4e690585-4986-48d9-a6cb-1a0d168fd06f'::uuid,
  '[TEST] Slice B — Random Draw Runtime',
  '2026-09-05 19:00:00+08'::timestamptz,
  '2026-09-04 00:00:00+08'::timestamptz,
  '2026-09-04 23:40:00+08'::timestamptz,
  '2026-09-04 23:45:00+08'::timestamptz,
  1,
  5,
  2,
  15,
  'https://example.invalid/umai-slice-b-runtime-test',
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
