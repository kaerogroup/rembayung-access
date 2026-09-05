-- Capacity-aware allocation production acceptance harness.
-- Uses one existing auth user, exercises real RPC/function boundaries, then cleans all fixtures.
-- Any failed assertion aborts the migration and rolls back.

do $$
declare
  v_user_id uuid;
  v_exact_session uuid := gen_random_uuid();
  v_exact_wave uuid := gen_random_uuid();
  v_exact_interest uuid;
  v_exact_key uuid;
  v_exact_key_after uuid;
  v_oversize_session uuid := gen_random_uuid();
  v_oversize_wave uuid := gen_random_uuid();
  v_oversize_interest uuid;
  v_count integer;
  v_selected_pax integer;
  v_status public.interest_status;
  v_out_of_range_rejected boolean := false;
begin
  select u.id
  into v_user_id
  from auth.users u
  order by u.created_at
  limit 1;

  if v_user_id is null then
    raise exception 'capacity runtime acceptance requires at least one auth user';
  end if;

  perform set_config('request.jwt.claim.sub', v_user_id::text, true);

  -- Exact-fit session: venue policy 3-8 pax, total allocation budget exactly 3 pax.
  insert into public.booking_sessions(
    id, title, starts_at, interest_opens_at, interest_closes_at, draw_starts_at,
    wave_size, wave_interval_minutes, max_waves, invitation_ttl_minutes,
    umai_url, status, min_party_size, max_party_size, allocation_capacity_pax
  ) values (
    v_exact_session,
    '[TEST] Capacity — Exact Fit',
    now() + interval '1 day',
    now() - interval '1 hour',
    now() + interval '1 hour',
    now() - interval '30 minutes',
    10, 5, 1, 30,
    'https://example.invalid/capacity-exact',
    'published',
    3, 8, 3
  );

  begin
    perform public.join_interest(v_exact_session, 2);
  exception
    when others then
      if sqlerrm like '%party_size_out_of_range%' then
        v_out_of_range_rejected := true;
      else
        raise;
      end if;
  end;

  if not v_out_of_range_rejected then
    raise exception 'session minimum party size was not enforced';
  end if;

  v_exact_interest := public.join_interest(v_exact_session, 3);

  select i.selection_key into v_exact_key
  from public.interests i
  where i.id = v_exact_interest;

  if not public.cancel_interest(v_exact_interest) then
    raise exception 'expected exact-fit interest cancellation to succeed';
  end if;

  if public.join_interest(v_exact_session, 3) is distinct from v_exact_interest then
    raise exception 'cancel/rejoin created a different interest identity';
  end if;

  select i.selection_key into v_exact_key_after
  from public.interests i
  where i.id = v_exact_interest;

  if v_exact_key_after is distinct from v_exact_key then
    raise exception 'cancel/rejoin rerolled stable selection priority';
  end if;

  insert into public.draw_waves(
    id, session_id, wave_no, scheduled_at, status
  ) values (
    v_exact_wave, v_exact_session, 1, '1900-01-01 00:00:00+00', 'scheduled'
  );

  perform * from public.process_due_wave();

  select i.status into v_status
  from public.interests i
  where i.id = v_exact_interest;

  if v_status <> 'selected' then
    raise exception 'exact-fit party was not selected';
  end if;

  select w.selected_count, w.selected_pax
  into v_count, v_selected_pax
  from public.draw_waves w
  where w.id = v_exact_wave;

  if v_count <> 1 or v_selected_pax <> 3 then
    raise exception 'exact-fit wave expected count=1 pax=3, got count=% pax=%', v_count, v_selected_pax;
  end if;

  select count(*) into v_count
  from public.invitations inv
  where inv.session_id = v_exact_session;

  if v_count <> 1 then
    raise exception 'exact-fit session expected exactly one invitation, got %', v_count;
  end if;

  -- Oversize session: party is valid for venue, but cannot fit remaining allocation budget.
  insert into public.booking_sessions(
    id, title, starts_at, interest_opens_at, interest_closes_at, draw_starts_at,
    wave_size, wave_interval_minutes, max_waves, invitation_ttl_minutes,
    umai_url, status, min_party_size, max_party_size, allocation_capacity_pax
  ) values (
    v_oversize_session,
    '[TEST] Capacity — Does Not Fit',
    now() + interval '1 day',
    now() - interval '1 hour',
    now() + interval '1 hour',
    now() - interval '30 minutes',
    10, 5, 1, 30,
    'https://example.invalid/capacity-oversize',
    'published',
    3, 8, 3
  );

  v_oversize_interest := public.join_interest(v_oversize_session, 4);

  insert into public.draw_waves(
    id, session_id, wave_no, scheduled_at, status
  ) values (
    v_oversize_wave, v_oversize_session, 1, '1900-01-02 00:00:00+00', 'scheduled'
  );

  perform * from public.process_due_wave();

  select i.status into v_status
  from public.interests i
  where i.id = v_oversize_interest;

  if v_status <> 'active' then
    raise exception 'oversize party should remain active, got %', v_status;
  end if;

  select w.selected_count, w.selected_pax
  into v_count, v_selected_pax
  from public.draw_waves w
  where w.id = v_oversize_wave;

  if v_count <> 0 or v_selected_pax <> 0 then
    raise exception 'oversize wave expected count=0 pax=0, got count=% pax=%', v_count, v_selected_pax;
  end if;

  select count(*) into v_count
  from public.invitations inv
  where inv.session_id = v_oversize_session;

  if v_count <> 0 then
    raise exception 'oversize party unexpectedly received invitation';
  end if;

  -- No due fixture remains, so a repeated processor call must create nothing.
  perform * from public.process_due_wave();

  select count(*) into v_count
  from public.invitations inv
  where inv.session_id in (v_exact_session, v_oversize_session);

  if v_count <> 1 then
    raise exception 'repeat processing changed entitlement count, got %', v_count;
  end if;

  -- Cleanup before commit. Email delivery rows cascade from invitation deletion.
  delete from public.invitations where session_id in (v_exact_session, v_oversize_session);
  delete from public.draw_waves where session_id in (v_exact_session, v_oversize_session);
  delete from public.interests where session_id in (v_exact_session, v_oversize_session);
  delete from public.booking_sessions where id in (v_exact_session, v_oversize_session);

  perform set_config('request.jwt.claim.sub', '', true);

  raise notice 'PASS: capacity party limits, stable priority, exact-fit pax budget, oversize rejection and idempotency verified';
end;
$$;
