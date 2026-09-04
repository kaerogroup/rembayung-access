-- Extend Slice B runtime acceptance window for 2026-09-05 morning verification.
-- Test session only; production booking semantics are unchanged.

update public.booking_sessions
set
  interest_opens_at = '2026-09-05 06:30:00+08'::timestamptz,
  interest_closes_at = '2026-09-05 07:00:00+08'::timestamptz,
  draw_starts_at = '2026-09-05 07:05:00+08'::timestamptz,
  wave_interval_minutes = 5,
  max_waves = 2,
  status = 'published'::public.session_status
where id = '4e690585-4986-48d9-a6cb-1a0d168fd06f'::uuid
  and title = '[TEST] Slice B — Random Draw Runtime';
