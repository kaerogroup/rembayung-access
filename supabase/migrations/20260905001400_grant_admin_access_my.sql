-- Grant the intended production operator account platform-admin membership.
-- Safety: require exactly one Auth identity for the configured email before granting.

do $$
declare
  v_match_count integer;
  v_user_id uuid;
begin
  select count(*)::integer, min(u.id)
  into v_match_count, v_user_id
  from auth.users u
  where lower(u.email) = lower('admin@access.my');

  if v_match_count <> 1 or v_user_id is null then
    raise exception 'admin_identity_not_unique: expected exactly one auth.users row for admin@access.my, found %', v_match_count;
  end if;

  insert into public.platform_admins(user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  if not exists (
    select 1
    from public.platform_admins a
    where a.user_id = v_user_id
  ) then
    raise exception 'admin_grant_verification_failed';
  end if;

  raise notice 'PASS: admin@access.my granted platform_admin membership';
end;
$$;
