-- Slice E operational bootstrap.
-- Grant platform-admin membership only when production still has exactly one Auth user,
-- no existing platform admin, and that sole user is the identity that exercised the
-- accepted golden-path session. Otherwise this migration intentionally does nothing.

do $$
declare
  v_auth_user_count integer;
  v_admin_count integer;
  v_only_user_id uuid;
  v_golden_path_user_count integer;
  v_golden_path_user_id uuid;
begin
  select count(*)::integer
  into v_auth_user_count
  from auth.users u;

  select u.id
  into v_only_user_id
  from auth.users u
  order by u.created_at, u.id
  limit 1;

  select count(*)::integer
  into v_admin_count
  from public.platform_admins;

  select count(distinct i.user_id)::integer
  into v_golden_path_user_count
  from public.interests i
  where i.session_id = 'f0cc7c5e-5812-47c9-a405-aed71cb4eb73'::uuid;

  select i.user_id
  into v_golden_path_user_id
  from public.interests i
  where i.session_id = 'f0cc7c5e-5812-47c9-a405-aed71cb4eb73'::uuid
  order by i.joined_at, i.id
  limit 1;

  if v_admin_count = 0
     and v_auth_user_count = 1
     and v_golden_path_user_count = 1
     and v_only_user_id is not null
     and v_golden_path_user_id = v_only_user_id then
    insert into public.platform_admins(user_id)
    values (v_only_user_id)
    on conflict (user_id) do nothing;

    raise notice 'PASS: sole accepted operator bootstrapped as platform admin';
  else
    raise notice 'SAFE NO-OP: admin bootstrap conditions not uniquely satisfied';
  end if;
end;
$$;
