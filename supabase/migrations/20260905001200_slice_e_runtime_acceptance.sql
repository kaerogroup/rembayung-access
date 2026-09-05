-- Slice E production acceptance harness.
-- Temporarily grants one existing auth user platform-admin membership, exercises the real
-- admin RPC authority, proves a non-admin identity is rejected, then removes all fixture state.

do $$
declare
  v_admin_id uuid;
  v_non_admin_id uuid := extensions.gen_random_uuid();
  v_session_id uuid;
  v_row record;
  v_count integer;
  v_status public.session_status;
  v_rejected boolean := false;
begin
  select u.id into v_admin_id
  from auth.users u
  order by u.created_at
  limit 1;

  if v_admin_id is null then
    raise exception 'Slice E runtime acceptance requires at least one auth user';
  end if;

  if exists (select 1 from public.platform_admins) then
    raise exception 'Slice E bootstrap acceptance expects empty platform_admins';
  end if;

  insert into public.platform_admins(user_id)
  values (v_admin_id);

  perform set_config('request.jwt.claim.sub', v_admin_id::text, true);

  if not public.is_platform_admin() then
    raise exception 'temporary admin membership was not recognized';
  end if;

  v_session_id := public.admin_create_session(
    '[TEST] Slice E — Minimum Admin Runtime',
    now() + interval '2 days',
    now() + interval '1 hour',
    now() + interval '12 hours',
    now() + interval '18 hours',
    3,
    8,
    120,
    20,
    12,
    3,
    10,
    'https://example.invalid/slice-e-admin'
  );

  select s.status into v_status
  from public.booking_sessions s
  where s.id = v_session_id;

  if v_status <> 'draft' then
    raise exception 'admin_create_session expected draft status, got %', v_status;
  end if;

  select * into v_row
  from public.admin_list_sessions() a
  where a.session_id = v_session_id;

  if not found then
    raise exception 'admin_list_sessions did not return created session';
  end if;

  if v_row.min_party_size <> 3
     or v_row.max_party_size <> 8
     or v_row.allocation_capacity_pax <> 120
     or v_row.interest_total <> 0
     or v_row.invitation_total <> 0
     or v_row.delivery_pending <> 0
     or v_row.delivery_sent <> 0 then
    raise exception 'admin operational projection did not preserve initial session configuration/state';
  end if;

  if not public.admin_publish_session(v_session_id) then
    raise exception 'admin_publish_session did not publish draft';
  end if;

  select s.status into v_status
  from public.booking_sessions s
  where s.id = v_session_id;

  if v_status <> 'published' then
    raise exception 'expected published status, got %', v_status;
  end if;

  -- A different authenticated identity without membership must not gain admin authority.
  perform set_config('request.jwt.claim.sub', v_non_admin_id::text, true);

  begin
    perform * from public.admin_list_sessions();
  exception
    when others then
      if sqlerrm like '%admin_required%' then
        v_rejected := true;
      else
        raise;
      end if;
  end;

  if not v_rejected then
    raise exception 'non-admin identity unexpectedly accessed admin session projection';
  end if;

  -- Restore the temporary admin identity for governed cleanup.
  perform set_config('request.jwt.claim.sub', v_admin_id::text, true);

  delete from public.booking_sessions
  where id = v_session_id;

  delete from public.platform_admins
  where user_id = v_admin_id;

  select count(*) into v_count
  from public.booking_sessions
  where id = v_session_id;

  if v_count <> 0 then
    raise exception 'Slice E fixture session cleanup failed';
  end if;

  select count(*) into v_count
  from public.platform_admins;

  if v_count <> 0 then
    raise exception 'Slice E temporary admin membership cleanup failed';
  end if;

  perform set_config('request.jwt.claim.sub', '', true);

  raise notice 'PASS: Slice E admin membership, create, observe, publish, rejection and cleanup verified';
end;
$$;
