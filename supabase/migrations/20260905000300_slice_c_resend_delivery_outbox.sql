-- Slice C: retryable invitation email delivery authority.
-- Plain invitation tokens are retained only in the RLS-protected outbox while
-- delivery is pending/retryable, then cleared after send or expiry.

alter table public.email_deliveries
  add column invitation_token text,
  add column next_attempt_at timestamptz not null default now(),
  add column claimed_at timestamptz;

create index email_deliveries_retry_idx
  on public.email_deliveries(status, next_attempt_at, created_at);

-- Invitations issued before Slice C cannot be reconstructed from token_hash.
-- Retire those legacy pending rows explicitly so they cannot loop forever.
update public.email_deliveries d
set
  status = 'failed',
  last_error = 'delivery payload unavailable: invitation issued before Slice C',
  next_attempt_at = now()
where d.status = 'pending'
  and d.invitation_token is null;

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
    v_expires_at := now() + make_interval(mins => v_session.invitation_ttl_minutes);

    insert into public.invitations(
      wave_id, interest_id, user_id, session_id, token_hash, expires_at
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

    wave_id := v_wave.id;
    invitation_id := v_invitation_id;
    user_id := v_interest.user_id;
    session_id := v_interest.session_id;
    token_plain := v_token;
    expires_at := v_expires_at;
    return next;
  end loop;

  update public.draw_waves
  set status = 'completed', processed_at = now(), selected_count = v_count
  where id = v_wave.id;
end;
$$;

revoke all on function public.process_due_wave() from public, anon, authenticated;
grant execute on function public.process_due_wave() to service_role;

create or replace function public.claim_pending_email_delivery()
returns table (
  delivery_id uuid,
  invitation_id uuid,
  recipient_email text,
  session_title text,
  invitation_token text,
  expires_at timestamptz,
  attempt_count integer
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_delivery_id uuid;
  v_invitation_id uuid;
  v_recipient_email text;
  v_session_title text;
  v_invitation_token text;
  v_expires_at timestamptz;
  v_attempt_count integer;
begin
  select
    d.id,
    d.invitation_id,
    u.email,
    s.title,
    d.invitation_token,
    i.expires_at,
    d.attempt_count + 1
  into
    v_delivery_id,
    v_invitation_id,
    v_recipient_email,
    v_session_title,
    v_invitation_token,
    v_expires_at,
    v_attempt_count
  from public.email_deliveries d
  join public.invitations i on i.id = d.invitation_id
  join public.booking_sessions s on s.id = i.session_id
  join auth.users u on u.id = i.user_id
  where d.provider = 'resend'
    and d.invitation_token is not null
    and u.email is not null
    and i.status = 'issued'
    and i.expires_at > now()
    and d.attempt_count < 5
    and (
      (
        d.status in ('pending', 'failed')
        and d.next_attempt_at <= now()
      )
      or (
        d.status = 'sending'
        and d.claimed_at is not null
        and d.claimed_at <= now() - interval '5 minutes'
      )
    )
  order by d.created_at, d.id
  for update of d skip locked
  limit 1;

  if not found then
    return;
  end if;

  update public.email_deliveries
  set
    status = 'sending',
    attempt_count = v_attempt_count,
    claimed_at = now(),
    last_error = null
  where id = v_delivery_id;

  delivery_id := v_delivery_id;
  invitation_id := v_invitation_id;
  recipient_email := v_recipient_email;
  session_title := v_session_title;
  invitation_token := v_invitation_token;
  expires_at := v_expires_at;
  attempt_count := v_attempt_count;
  return next;
end;
$$;

revoke all on function public.claim_pending_email_delivery() from public, anon, authenticated;
grant execute on function public.claim_pending_email_delivery() to service_role;

create or replace function public.complete_email_delivery(
  p_delivery_id uuid,
  p_provider_message_id text
)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_rows integer;
begin
  update public.email_deliveries
  set
    status = 'sent',
    provider_message_id = left(p_provider_message_id, 255),
    sent_at = now(),
    claimed_at = null,
    last_error = null,
    invitation_token = null
  where id = p_delivery_id
    and status = 'sending';

  get diagnostics v_rows = row_count;
  return v_rows = 1;
end;
$$;

revoke all on function public.complete_email_delivery(uuid, text) from public, anon, authenticated;
grant execute on function public.complete_email_delivery(uuid, text) to service_role;

create or replace function public.fail_email_delivery(
  p_delivery_id uuid,
  p_error text
)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_rows integer;
begin
  update public.email_deliveries
  set
    status = 'failed',
    claimed_at = null,
    last_error = left(coalesce(p_error, 'unknown delivery failure'), 500),
    next_attempt_at = now() + make_interval(
      mins => least(30, greatest(1, attempt_count * 2))
    )
  where id = p_delivery_id
    and status = 'sending';

  get diagnostics v_rows = row_count;
  return v_rows = 1;
end;
$$;

revoke all on function public.fail_email_delivery(uuid, text) from public, anon, authenticated;
grant execute on function public.fail_email_delivery(uuid, text) to service_role;

create or replace function public.expire_email_deliveries()
returns integer
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_rows integer;
begin
  update public.email_deliveries d
  set
    status = 'failed',
    claimed_at = null,
    last_error = 'invitation expired before email delivery',
    invitation_token = null
  from public.invitations i
  where i.id = d.invitation_id
    and i.expires_at <= now()
    and d.status <> 'sent'
    and d.invitation_token is not null;

  get diagnostics v_rows = row_count;
  return v_rows;
end;
$$;

revoke all on function public.expire_email_deliveries() from public, anon, authenticated;
grant execute on function public.expire_email_deliveries() to service_role;
