-- Slice B: deterministic wave schedule materialization.
-- Published sessions define their draw schedule; this function idempotently creates
-- the draw_waves consumed by process_due_wave().

create or replace function public.ensure_draw_waves()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted integer := 0;
begin
  insert into public.draw_waves (
    session_id,
    wave_no,
    scheduled_at,
    status
  )
  select
    s.id,
    wave_no,
    s.draw_starts_at + make_interval(mins => (wave_no - 1) * s.wave_interval_minutes),
    'scheduled'::public.wave_status
  from public.booking_sessions s
  cross join lateral generate_series(1, s.max_waves) as wave_no
  where s.status = 'published'
  on conflict (session_id, wave_no) do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

revoke all on function public.ensure_draw_waves() from public, anon, authenticated;
grant execute on function public.ensure_draw_waves() to service_role;

-- process_due_wave is also a server-only authority. Keep its intended execution
-- boundary explicit for the Cloudflare broadcast worker.
grant execute on function public.process_due_wave() to service_role;
