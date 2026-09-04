-- Extend Slice B runtime acceptance window after CI/CD recovery.
-- This changes only the fixed test session; production booking semantics are unchanged.

update public.booking_sessions
set
  interest_closes_at = '2026-09-05 00:10:00+08'::timestamptz,
  draw_starts_at = '2026-09-05 00:15:00+08'::timestamptz,
  wave_interval_minutes = 5,
  max_waves = 2
where id = '4e690585-4986-48d9-a6cb-1a0d168fd06f'::uuid
  and title = '[TEST] Slice B — Random Draw Runtime';
