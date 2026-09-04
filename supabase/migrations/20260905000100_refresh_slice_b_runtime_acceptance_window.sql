-- Refresh Slice B runtime acceptance window after CI/CD recovery.
-- This changes only the fixed test session; production booking semantics are unchanged.

update public.booking_sessions
set
  interest_opens_at = '2026-09-05 06:45:00+08'::timestamptz,
  interest_closes_at = '2026-09-05 07:30:00+08'::timestamptz,
  draw_starts_at = '2026-09-05 07:35:00+08'::timestamptz,
  wave_size = 1,
  wave_interval_minutes = 5,
  max_waves = 2,
  invitation_ttl_minutes = 15,
  status = 'published'::public.session_status
where id = '4e690585-4986-48d9-a6cb-1a0d168fd06f'::uuid
  and title = '[TEST] Slice B — Random Draw Runtime';

-- Reset only this fixed acceptance session so the scheduler can materialize
-- fresh waves for the refreshed window. No production session is affected.
delete from public.email_deliveries
where invitation_id in (
  select id from public.invitations
  where session_id = '4e690585-4986-48d9-a6cb-1a0d168fd06f'::uuid
);

delete from public.invitations
where session_id = '4e690585-4986-48d9-a6cb-1a0d168fd06f'::uuid;

delete from public.draw_waves
where session_id = '4e690585-4986-48d9-a6cb-1a0d168fd06f'::uuid;

update public.interests
set status = 'active'::public.interest_status,
    selected_at = null
where session_id = '4e690585-4986-48d9-a6cb-1a0d168fd06f'::uuid;
