drop policy if exists "users insert own interests" on public.interests;
drop policy if exists "users update own active interests" on public.interests;

revoke insert, update, delete on table public.interests from anon, authenticated;

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
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;

  if p_party_size < 2 or p_party_size > 8 then
    raise exception 'party_size_out_of_range';
  end if;

  if not exists (
    select 1
    from public.booking_sessions s
    where s.id = p_session_id
      and s.status = 'published'
      and now() between s.interest_opens_at and s.interest_closes_at
  ) then
    raise exception 'interest_window_closed';
  end if;

  insert into public.interests(user_id, session_id, party_size, status, joined_at, selected_at)
  values (v_user_id, p_session_id, p_party_size, 'active', now(), null)
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

create or replace function public.cancel_interest(p_interest_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_updated integer := 0;
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;

  update public.interests
  set status = 'cancelled'
  where id = p_interest_id
    and user_id = v_user_id
    and status = 'active';

  get diagnostics v_updated = row_count;
  return v_updated = 1;
end;
$$;

revoke all on function public.join_interest(uuid, integer) from public, anon;
revoke all on function public.cancel_interest(uuid) from public, anon;
grant execute on function public.join_interest(uuid, integer) to authenticated;
grant execute on function public.cancel_interest(uuid) to authenticated;
