-- Capacity-aware allocation load/fairness acceptance.
-- Creates 120 synthetic candidate UUID references without inserting fake auth.users.
-- Auth foreign keys are deferred only inside this migration transaction; all fixture rows
-- are removed and constraints are restored to normal immediate semantics before commit.

alter table public.interests
  alter constraint interests_user_id_fkey deferrable initially immediate;

alter table public.invitations
  alter constraint invitations_user_id_fkey deferrable initially immediate;

do $$
declare
  v_session_id uuid := extensions.gen_random_uuid();
  v_wave_id uuid := extensions.gen_random_uuid();
  v_candidate record;
  v_expected_count integer := 0;
  v_expected_pax integer := 0;
  v_remaining_pax integer := 240;
  v_actual_count integer;
  v_actual_pax integer;
  v_invitation_count integer;
  v_mismatch_count integer;
  v_latest_status public.interest_status;
  v_earliest_status public.interest_status;
  v_total_candidates integer;
begin
  set constraints interests_user_id_fkey, invitations_user_id_fkey deferred;

  create temporary table capacity_expected_selected (
    interest_id uuid primary key,
    party_size integer not null,
    selection_key uuid not null
  ) on commit drop;

  insert into public.booking_sessions(
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
    status,
    min_party_size,
    max_party_size,
    allocation_capacity_pax
  ) values (
    v_session_id,
    '[TEST] Capacity — 120 Candidate Fairness Load',
    now() + interval '1 day',
    now() - interval '2 hours',
    now() - interval '1 hour',
    now() - interval '30 minutes',
    120,
    5,
    1,
    30,
    'https://example.invalid/capacity-load',
    'published',
    2,
    8,
    240
  );

  -- 120 unique synthetic user UUID references. No rows are inserted into auth.users.
  -- joined_at increases with g, while selection_key is deliberately reversed so this
  -- fixture proves allocation is priority-driven rather than first-come-first-served.
  insert into public.interests(
    user_id,
    session_id,
    party_size,
    status,
    joined_at,
    selected_at,
    selection_key
  )
  select
    extensions.gen_random_uuid(),
    v_session_id,
    2 + ((g - 1) % 7),
    'active'::public.interest_status,
    now() - interval '10 minutes' + make_interval(secs => g),
    null,
    (
      '00000000-0000-0000-0000-' ||
      lpad(to_hex(121 - g), 12, '0')
    )::uuid
  from generate_series(1, 120) as g;

  select count(*) into v_total_candidates
  from public.interests i
  where i.session_id = v_session_id;

  if v_total_candidates <> 120 then
    raise exception 'expected 120 synthetic candidates, got %', v_total_candidates;
  end if;

  -- Calculate the expected set using the same externally observable contract:
  -- stable selection_key order, wave-size ceiling and remaining-pax fit rule.
  for v_candidate in
    select i.id, i.party_size, i.selection_key
    from public.interests i
    where i.session_id = v_session_id
      and i.status = 'active'
    order by i.selection_key
  loop
    exit when v_expected_count >= 120;
    exit when v_remaining_pax <= 0;

    if v_candidate.party_size > v_remaining_pax then
      continue;
    end if;

    insert into capacity_expected_selected(interest_id, party_size, selection_key)
    values (v_candidate.id, v_candidate.party_size, v_candidate.selection_key);

    v_expected_count := v_expected_count + 1;
    v_expected_pax := v_expected_pax + v_candidate.party_size;
    v_remaining_pax := v_remaining_pax - v_candidate.party_size;
  end loop;

  if v_expected_count <= 1 or v_expected_count >= 120 then
    raise exception 'load fixture did not produce a meaningful partial allocation: % selected', v_expected_count;
  end if;

  if 240 - v_expected_pax >= 2 then
    raise exception 'expected allocation should leave less than minimum party size unused, got % pax free', 240 - v_expected_pax;
  end if;

  insert into public.draw_waves(
    id,
    session_id,
    wave_no,
    scheduled_at,
    status
  ) values (
    v_wave_id,
    v_session_id,
    1,
    '1900-01-03 00:00:00+00',
    'scheduled'
  );

  perform * from public.process_due_wave();

  select w.selected_count, w.selected_pax
  into v_actual_count, v_actual_pax
  from public.draw_waves w
  where w.id = v_wave_id;

  if v_actual_count is distinct from v_expected_count
     or v_actual_pax is distinct from v_expected_pax then
    raise exception
      '120-candidate allocation mismatch: expected count=% pax=%, actual count=% pax=%',
      v_expected_count,
      v_expected_pax,
      v_actual_count,
      v_actual_pax;
  end if;

  select count(*) into v_mismatch_count
  from (
    (
      select i.id
      from public.interests i
      where i.session_id = v_session_id
        and i.status = 'selected'
      except
      select e.interest_id
      from capacity_expected_selected e
    )
    union all
    (
      select e.interest_id
      from capacity_expected_selected e
      except
      select i.id
      from public.interests i
      where i.session_id = v_session_id
        and i.status = 'selected'
    )
  ) mismatches;

  if v_mismatch_count <> 0 then
    raise exception 'selected candidate set diverged from stable-priority capacity contract';
  end if;

  select count(*) into v_invitation_count
  from public.invitations inv
  where inv.session_id = v_session_id;

  if v_invitation_count <> v_expected_count then
    raise exception 'expected one invitation per selected interest: expected %, got %',
      v_expected_count, v_invitation_count;
  end if;

  -- The newest joined candidate has the smallest selection_key and must be selected;
  -- the oldest joined candidate has the largest selection_key and should remain active
  -- once the 240-pax budget is exhausted. This proves selection is not FCFS.
  select i.status into v_latest_status
  from public.interests i
  where i.session_id = v_session_id
  order by i.joined_at desc
  limit 1;

  select i.status into v_earliest_status
  from public.interests i
  where i.session_id = v_session_id
  order by i.joined_at asc
  limit 1;

  if v_latest_status <> 'selected' then
    raise exception 'stable priority failed: latest-joined/highest-priority candidate was not selected';
  end if;

  if v_earliest_status <> 'active' then
    raise exception 'allocation appears FCFS-like: earliest-joined/lowest-priority candidate should remain active';
  end if;

  -- Idempotency: no scheduled fixture wave remains, so another processor call cannot
  -- create new entitlement or change the already-completed wave accounting.
  perform * from public.process_due_wave();

  select count(*) into v_invitation_count
  from public.invitations inv
  where inv.session_id = v_session_id;

  if v_invitation_count <> v_expected_count then
    raise exception 'repeat processing changed invitation entitlement count: expected %, got %',
      v_expected_count, v_invitation_count;
  end if;

  select w.selected_count, w.selected_pax
  into v_actual_count, v_actual_pax
  from public.draw_waves w
  where w.id = v_wave_id;

  if v_actual_count <> v_expected_count or v_actual_pax <> v_expected_pax then
    raise exception 'repeat processing changed completed wave accounting';
  end if;

  -- Remove every fixture row before constraints return to immediate mode.
  delete from public.invitations where session_id = v_session_id;
  delete from public.draw_waves where session_id = v_session_id;
  delete from public.interests where session_id = v_session_id;
  delete from public.booking_sessions where id = v_session_id;

  set constraints interests_user_id_fkey, invitations_user_id_fkey immediate;

  raise notice
    'PASS: 120-candidate mixed-party fairness load verified; selected=% pax=% remaining=%',
    v_expected_count,
    v_expected_pax,
    240 - v_expected_pax;
end;
$$;

alter table public.interests
  alter constraint interests_user_id_fkey not deferrable;

alter table public.invitations
  alter constraint invitations_user_id_fkey not deferrable;
