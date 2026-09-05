-- Slice E: minimum admin authority for session configuration and operational observation.
-- Browser users never receive direct write access to booking/session authority tables.

create table public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.platform_admins enable row level security;

revoke all on table public.platform_admins from anon, authenticated;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.platform_admins a
      where a.user_id = auth.uid()
    );
$$;

revoke all on function public.is_platform_admin() from public, anon;
grant execute on function public.is_platform_admin() to authenticated;

create or replace function public.grant_platform_admin(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not exists (select 1 from auth.users u where u.id = p_user_id) then
    raise exception 'admin_user_not_found';
  end if;

  insert into public.platform_admins(user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  return true;
end;
$$;

revoke all on function public.grant_platform_admin(uuid) from public, anon, authenticated;
grant execute on function public.grant_platform_admin(uuid) to service_role;

create or replace function public.revoke_platform_admin(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_rows integer;
begin
  delete from public.platform_admins
  where user_id = p_user_id;

  get diagnostics v_rows = row_count;
  return v_rows = 1;
end;
$$;

revoke all on function public.revoke_platform_admin(uuid) from public, anon, authenticated;
grant execute on function public.revoke_platform_admin(uuid) to service_role;

create or replace function public.admin_create_session(
  p_title text,
  p_starts_at timestamptz,
  p_interest_opens_at timestamptz,
  p_interest_closes_at timestamptz,
  p_draw_starts_at timestamptz,
  p_min_party_size integer,
  p_max_party_size integer,
  p_allocation_capacity_pax integer,
  p_wave_size integer,
  p_wave_interval_minutes integer,
  p_max_waves integer,
  p_invitation_ttl_minutes integer,
  p_umai_url text
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_session_id uuid;
  v_title text := btrim(coalesce(p_title, ''));
  v_umai_url text := btrim(coalesce(p_umai_url, ''));
begin
  if not public.is_platform_admin() then
    raise exception 'admin_required';
  end if;

  if char_length(v_title) < 3 or char_length(v_title) > 160 then
    raise exception 'session_title_invalid';
  end if;

  if p_interest_opens_at >= p_interest_closes_at
     or p_interest_closes_at > p_draw_starts_at
     or p_draw_starts_at >= p_starts_at then
    raise exception 'session_timeline_invalid';
  end if;

  if v_umai_url !~ '^https://[^[:space:]]+$' then
    raise exception 'downstream_url_invalid';
  end if;

  insert into public.booking_sessions(
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
    v_title,
    p_starts_at,
    p_interest_opens_at,
    p_interest_closes_at,
    p_draw_starts_at,
    p_wave_size,
    p_wave_interval_minutes,
    p_max_waves,
    p_invitation_ttl_minutes,
    v_umai_url,
    'draft',
    p_min_party_size,
    p_max_party_size,
    p_allocation_capacity_pax
  )
  returning id into v_session_id;

  return v_session_id;
end;
$$;

revoke all on function public.admin_create_session(
  text, timestamptz, timestamptz, timestamptz, timestamptz,
  integer, integer, integer, integer, integer, integer, integer, text
) from public, anon;
grant execute on function public.admin_create_session(
  text, timestamptz, timestamptz, timestamptz, timestamptz,
  integer, integer, integer, integer, integer, integer, integer, text
) to authenticated;

create or replace function public.admin_publish_session(p_session_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_session public.booking_sessions%rowtype;
  v_rows integer;
begin
  if not public.is_platform_admin() then
    raise exception 'admin_required';
  end if;

  select * into v_session
  from public.booking_sessions s
  where s.id = p_session_id
  for update;

  if not found then
    raise exception 'session_not_found';
  end if;

  if v_session.status = 'published' then
    return true;
  end if;

  if v_session.status <> 'draft' then
    raise exception 'session_not_publishable';
  end if;

  if v_session.draw_starts_at <= now()
     or v_session.starts_at <= now() then
    raise exception 'session_schedule_not_future';
  end if;

  update public.booking_sessions
  set status = 'published'
  where id = p_session_id
    and status = 'draft';

  get diagnostics v_rows = row_count;
  return v_rows = 1;
end;
$$;

revoke all on function public.admin_publish_session(uuid) from public, anon;
grant execute on function public.admin_publish_session(uuid) to authenticated;

create or replace function public.admin_list_sessions()
returns table (
  session_id uuid,
  title text,
  starts_at timestamptz,
  interest_opens_at timestamptz,
  interest_closes_at timestamptz,
  draw_starts_at timestamptz,
  status public.session_status,
  min_party_size integer,
  max_party_size integer,
  allocation_capacity_pax integer,
  wave_size integer,
  wave_interval_minutes integer,
  max_waves integer,
  invitation_ttl_minutes integer,
  umai_url text,
  interest_total bigint,
  interest_active bigint,
  interest_selected bigint,
  wave_scheduled bigint,
  wave_completed bigint,
  wave_failed bigint,
  invitation_total bigint,
  delivery_pending bigint,
  delivery_sending bigint,
  delivery_sent bigint,
  delivery_failed bigint
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'admin_required';
  end if;

  return query
  select
    s.id,
    s.title,
    s.starts_at,
    s.interest_opens_at,
    s.interest_closes_at,
    s.draw_starts_at,
    s.status,
    s.min_party_size,
    s.max_party_size,
    s.allocation_capacity_pax,
    s.wave_size,
    s.wave_interval_minutes,
    s.max_waves,
    s.invitation_ttl_minutes,
    s.umai_url,
    (select count(*) from public.interests i where i.session_id = s.id),
    (select count(*) from public.interests i where i.session_id = s.id and i.status = 'active'),
    (select count(*) from public.interests i where i.session_id = s.id and i.status = 'selected'),
    (select count(*) from public.draw_waves w where w.session_id = s.id and w.status = 'scheduled'),
    (select count(*) from public.draw_waves w where w.session_id = s.id and w.status = 'completed'),
    (select count(*) from public.draw_waves w where w.session_id = s.id and w.status = 'failed'),
    (select count(*) from public.invitations inv where inv.session_id = s.id),
    (
      select count(*)
      from public.email_deliveries d
      join public.invitations inv on inv.id = d.invitation_id
      where inv.session_id = s.id and d.status = 'pending'
    ),
    (
      select count(*)
      from public.email_deliveries d
      join public.invitations inv on inv.id = d.invitation_id
      where inv.session_id = s.id and d.status = 'sending'
    ),
    (
      select count(*)
      from public.email_deliveries d
      join public.invitations inv on inv.id = d.invitation_id
      where inv.session_id = s.id and d.status = 'sent'
    ),
    (
      select count(*)
      from public.email_deliveries d
      join public.invitations inv on inv.id = d.invitation_id
      where inv.session_id = s.id and d.status = 'failed'
    )
  from public.booking_sessions s
  order by s.starts_at desc, s.created_at desc;
end;
$$;

revoke all on function public.admin_list_sessions() from public, anon;
grant execute on function public.admin_list_sessions() to authenticated;
