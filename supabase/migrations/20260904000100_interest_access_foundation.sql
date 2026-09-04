create extension if not exists pgcrypto;

create type public.session_status as enum ('draft','published','closed','completed','cancelled');
create type public.interest_status as enum ('active','selected','cancelled','closed');
create type public.wave_status as enum ('scheduled','processing','completed','failed');
create type public.invitation_status as enum ('issued','opened','redirected','expired','revoked');
create type public.delivery_status as enum ('pending','sending','sent','failed');

create table public.booking_sessions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  starts_at timestamptz not null,
  interest_opens_at timestamptz not null,
  interest_closes_at timestamptz not null,
  draw_starts_at timestamptz not null,
  wave_size integer not null check (wave_size > 0),
  wave_interval_minutes integer not null default 12 check (wave_interval_minutes between 1 and 120),
  max_waves integer not null default 3 check (max_waves between 1 and 20),
  invitation_ttl_minutes integer not null default 10 check (invitation_ttl_minutes between 1 and 120),
  umai_url text not null,
  status public.session_status not null default 'draft',
  created_at timestamptz not null default now(),
  check (interest_opens_at < interest_closes_at),
  check (interest_closes_at <= draw_starts_at)
);

create table public.interests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null references public.booking_sessions(id) on delete cascade,
  party_size integer not null check (party_size between 2 and 8),
  status public.interest_status not null default 'active',
  joined_at timestamptz not null default now(),
  selected_at timestamptz,
  unique (user_id, session_id)
);

create table public.draw_waves (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.booking_sessions(id) on delete cascade,
  wave_no integer not null check (wave_no > 0),
  scheduled_at timestamptz not null,
  processed_at timestamptz,
  status public.wave_status not null default 'scheduled',
  selected_count integer not null default 0,
  error_message text,
  unique (session_id, wave_no)
);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  wave_id uuid not null references public.draw_waves(id) on delete restrict,
  interest_id uuid not null unique references public.interests(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  session_id uuid not null references public.booking_sessions(id) on delete restrict,
  token_hash text not null unique,
  status public.invitation_status not null default 'issued',
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  opened_at timestamptz,
  redirected_at timestamptz
);

create table public.email_deliveries (
  id uuid primary key default gen_random_uuid(),
  invitation_id uuid not null references public.invitations(id) on delete cascade,
  provider text not null default 'resend',
  provider_message_id text,
  status public.delivery_status not null default 'pending',
  attempt_count integer not null default 0,
  last_error text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  unique (invitation_id, provider)
);

create table public.redirect_audits (
  id uuid primary key default gen_random_uuid(),
  invitation_id uuid not null references public.invitations(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  redirected_at timestamptz not null default now(),
  user_agent_hash text
);

create index interests_session_active_idx on public.interests(session_id, status);
create index draw_waves_due_idx on public.draw_waves(status, scheduled_at);
create index invitations_user_idx on public.invitations(user_id, session_id);
create index email_deliveries_pending_idx on public.email_deliveries(status, created_at);

alter table public.booking_sessions enable row level security;
alter table public.interests enable row level security;
alter table public.draw_waves enable row level security;
alter table public.invitations enable row level security;
alter table public.email_deliveries enable row level security;
alter table public.redirect_audits enable row level security;

create policy "published sessions readable"
on public.booking_sessions for select
to authenticated
using (status = 'published');

create policy "users read own interests"
on public.interests for select
to authenticated
using (user_id = auth.uid());

create policy "users insert own interests"
on public.interests for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.booking_sessions s
    where s.id = session_id
      and s.status = 'published'
      and now() between s.interest_opens_at and s.interest_closes_at
  )
);

create policy "users update own active interests"
on public.interests for update
to authenticated
using (user_id = auth.uid() and status = 'active')
with check (user_id = auth.uid());

create policy "users read own invitations"
on public.invitations for select
to authenticated
using (user_id = auth.uid());

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
    v_token := encode(gen_random_bytes(32), 'hex');

    insert into public.invitations(
      wave_id, interest_id, user_id, session_id, token_hash, expires_at
    ) values (
      v_wave.id,
      v_interest.id,
      v_interest.user_id,
      v_interest.session_id,
      encode(digest(v_token, 'sha256'), 'hex'),
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
