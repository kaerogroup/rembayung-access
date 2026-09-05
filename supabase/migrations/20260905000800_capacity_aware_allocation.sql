-- Capacity-aware fair allocation.
-- Keeps random-first fairness while making venue/session party-size and pax budget explicit.

alter table public.booking_sessions
  add column min_party_size integer not null default 2,
  add column max_party_size integer not null default 8,
  add column allocation_capacity_pax integer;

alter table public.booking_sessions
  add constraint booking_sessions_party_size_range_check
    check (
      min_party_size >= 1
      and max_party_size >= min_party_size
      and max_party_size <= 100
    ),
  add constraint booking_sessions_allocation_capacity_check
    check (allocation_capacity_pax is null or allocation_capacity_pax > 0);

-- Keep the interest row generically reusable; session policy is authoritative.
alter table public.interests
  drop constraint if exists interests_party_size_check;

alter table public.interests
  add constraint interests_party_size_positive_check
    check (party_size between 1 and 100),
  add column selection_key uuid not null default gen_random_uuid();

create index interests_session_selection_idx
  on public.interests(session_id, status, selection_key);

alter table public.draw_waves
  add column selected_pax integer not null default 0
    check (selected_pax >= 0);

create or replace function public.join_interest(
  p_session_id uuid,
  p_party_size integer
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_interest_id uuid;
  v_session public.booking_sessions%rowtype;
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;

  select * into v_session
  from public.booking_sessions s
  where s.id = p_session_id
    and s.status = 'published'
    and now() between s.interest_opens_at and s.interest_closes_at;

  if not found then
    raise exception 'interest_window_closed';
  end if;

  if p_party_size < v_session.min_party_size
     or p_party_size > v_session.max_party_size then
    raise exception 'party_size_out_of_range';
  end if;

  insert into public.interests(
    user_id,
    session_id,
    party_size,
    status,
    joined_at,
    selected_at
  )
  values (
    v_user_id,
    p_session_id,
    p_party_size,
    'active',
    now(),
    null
  )
  on conflict (user_id, session_id)
  do update
    set party_size = excluded.party_size,
        status = 'active',
        joined_at = now(),
        selected_at = null
  where public.interests.status = 'cancelled'
  returning id into v_interest_id;

  if v_interest_id is null then
    select id into v_interest_id
    from public.interests
    where user_id = v_user_id
      and session_id = p_session_id
      and status = 'active';
  end if;

  if v_interest_id is null then
    raise exception 'interest_not_joinable';
  end if;

  return v_interest_id;
end;
$$;

revoke all on function public.join_interest(uuid, integer) from public, anon;
grant execute on function public.join_interest(uuid, integer) to authenticated;

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
  v_expires_at timestamptz;
  v_count integer := 0;
  v_selected_pax integer := 0;
  v_already_selected_pax integer := 0;
  v_remaining_pax integer;
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

  -- Serialize allocation for waves belonging to the same session so two due
  -- waves cannot race and exceed the same pax budget.
  select * into v_session
  from public.booking_sessions
  where id = v_wave.session_id
  for update;

  select coalesce(sum(i.party_size), 0)::integer
  into v_already_selected_pax
  from public.interests i
  where i.session_id = v_wave.session_id
    and i.status = 'selected';

  if v_session.allocation_capacity_pax is null then
    v_remaining_pax := null;
  else
    v_remaining_pax := greatest(
      0,
      v_session.allocation_capacity_pax - v_already_selected_pax
    );
  end if;

  for v_interest in
    select i.*
    from public.interests i
    where i.session_id = v_wave.session_id
      and i.status = 'active'
    order by i.selection_key
    for update skip locked
  loop
    exit when v_count >= v_session.wave_size;

    if v_remaining_pax is not null then
      exit when v_remaining_pax <= 0;

      -- Stable random priority is preserved, but a party that cannot fit the
      -- remaining budget is skipped so a later smaller party may still fit.
      if v_interest.party_size > v_remaining_pax then
        continue;
      end if;
    end if;

    v_token := encode(extensions.gen_random_bytes(32), 'hex');
    v_expires_at := now() + make_interval(mins => v_session.invitation_ttl_minutes);

    insert into public.invitations(
      wave_id,
      interest_id,
      user_id,
      session_id,
      token_hash,
      expires_at
    ) values (
      v_wave.id,
      v_interest.id,
      v_interest.user_id,
      v_interest.session_id,
      encode(extensions.digest(v_token, 'sha256'), 'hex'),
      v_expires_at
    ) returning id into v_invitation_id;

    insert into public.email_deliveries(invitation_id, invitation_token)
    values (v_invitation_id, v_token);

    update public.interests
    set status = 'selected', selected_at = now()
    where id = v_interest.id;

    v_count := v_count + 1;
    v_selected_pax := v_selected_pax + v_interest.party_size;

    if v_remaining_pax is not null then
      v_remaining_pax := v_remaining_pax - v_interest.party_size;
    end if;

    wave_id := v_wave.id;
    invitation_id := v_invitation_id;
    user_id := v_interest.user_id;
    session_id := v_interest.session_id;
    token_plain := v_token;
    expires_at := v_expires_at;
    return next;
  end loop;

  update public.draw_waves
  set
    status = 'completed',
    processed_at = now(),
    selected_count = v_count,
    selected_pax = v_selected_pax,
    error_message = null
  where id = v_wave.id;
end;
$$;

revoke all on function public.process_due_wave() from public, anon, authenticated;
grant execute on function public.process_due_wave() to service_role;
