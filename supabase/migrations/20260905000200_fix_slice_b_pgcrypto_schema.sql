-- Slice B runtime fix: Supabase installs pgcrypto under the extensions schema.
-- process_due_wave() uses a restricted search_path, so pgcrypto routines must be
-- schema-qualified rather than relying on ambient search_path resolution.

create or replace function public.process_due_wave()
returns table (
  wave_id uuid,
  invitation_id uuid,
  user_id uuid,
  session_id uuid,
  token_plain text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_wave public.draw_waves%rowtype;
  v_session public.booking_sessions%rowtype;
  v_interest public.interests%rowtype;
  v_token text;
  v_invitation_id uuid;
  v_count integer := 0;
begin
  select * into v_wave
  from public.draw_waves
  where status = 'scheduled'
    and scheduled_at <= now()
  order by scheduled_at, wave_no
  for update skip locked
  limit 1;

  if not found then
    return;
  end if;

  update public.draw_waves
  set status = 'processing'
  where id = v_wave.id;

  select * into v_session
  from public.booking_sessions
  where id = v_wave.session_id;

  for v_interest in
    select i.*
    from public.interests i
    where i.session_id = v_wave.session_id
      and i.status = 'active'
    order by gen_random_uuid()
    limit v_session.wave_size
    for update skip locked
  loop
    v_token := encode(extensions.gen_random_bytes(32), 'hex');

    insert into public.invitations(
      wave_id, interest_id, user_id, session_id, token_hash, expires_at
    ) values (
      v_wave.id,
      v_interest.id,
      v_interest.user_id,
      v_interest.session_id,
      encode(extensions.digest(v_token, 'sha256'), 'hex'),
      now() + make_interval(mins => v_session.invitation_ttl_minutes)
    ) returning id into v_invitation_id;

    insert into public.email_deliveries(invitation_id)
    values (v_invitation_id);

    update public.interests
    set status = 'selected', selected_at = now()
    where id = v_interest.id;

    v_count := v_count + 1;

    wave_id := v_wave.id;
    invitation_id := v_invitation_id;
    user_id := v_interest.user_id;
    session_id := v_interest.session_id;
    token_plain := v_token;
    expires_at := now() + make_interval(mins => v_session.invitation_ttl_minutes);
    return next;
  end loop;

  update public.draw_waves
  set status = 'completed', processed_at = now(), selected_count = v_count
  where id = v_wave.id;
end;
$$;

revoke all on function public.process_due_wave() from public, anon, authenticated;
grant execute on function public.process_due_wave() to service_role;
