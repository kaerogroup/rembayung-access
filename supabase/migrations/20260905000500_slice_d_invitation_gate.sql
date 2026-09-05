-- Slice D: authenticated invitation gate and audited UMAI redirect.
-- The browser presents the invitation token, but PostgreSQL remains the authority
-- for ownership, token hash, expiry, revocation, state transition and destination.

create or replace function public.open_invitation(p_token text)
returns table (
  invitation_id uuid,
  session_id uuid,
  session_title text,
  session_starts_at timestamptz,
  party_size integer,
  invitation_status public.invitation_status,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_invitation public.invitations%rowtype;
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  if p_token is null or length(p_token) < 32 then
    return;
  end if;

  select i.*
  into v_invitation
  from public.invitations i
  where i.user_id = v_user_id
    and i.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  for update;

  if not found then
    return;
  end if;

  if v_invitation.expires_at <= now()
    and v_invitation.status not in ('expired', 'revoked') then
    update public.invitations
    set status = 'expired'
    where id = v_invitation.id;
    v_invitation.status := 'expired';
  elsif v_invitation.status = 'issued' then
    update public.invitations
    set
      status = 'opened',
      opened_at = coalesce(opened_at, now())
    where id = v_invitation.id;
    v_invitation.status := 'opened';
  end if;

  return query
  select
    v_invitation.id,
    s.id,
    s.title,
    s.starts_at,
    interests.party_size,
    v_invitation.status,
    v_invitation.expires_at
  from public.booking_sessions s
  join public.interests on interests.id = v_invitation.interest_id
  where s.id = v_invitation.session_id;
end;
$$;

revoke all on function public.open_invitation(text) from public, anon;
grant execute on function public.open_invitation(text) to authenticated;

create or replace function public.redirect_invitation(
  p_token text,
  p_user_agent_hash text default null
)
returns table (
  invitation_id uuid,
  destination_url text
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_invitation public.invitations%rowtype;
  v_destination text;
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  if p_token is null or length(p_token) < 32 then
    return;
  end if;

  select i.*
  into v_invitation
  from public.invitations i
  where i.user_id = v_user_id
    and i.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  for update;

  if not found then
    return;
  end if;

  if v_invitation.expires_at <= now() then
    if v_invitation.status not in ('expired', 'revoked') then
      update public.invitations
      set status = 'expired'
      where id = v_invitation.id;
    end if;
    return;
  end if;

  if v_invitation.status in ('expired', 'revoked') then
    return;
  end if;

  select s.umai_url
  into v_destination
  from public.booking_sessions s
  where s.id = v_invitation.session_id;

  if v_destination is null or btrim(v_destination) = '' then
    return;
  end if;

  update public.invitations
  set
    status = 'redirected',
    opened_at = coalesce(opened_at, now()),
    redirected_at = coalesce(redirected_at, now())
  where id = v_invitation.id;

  insert into public.redirect_audits(
    invitation_id,
    user_id,
    user_agent_hash
  ) values (
    v_invitation.id,
    v_user_id,
    left(nullif(btrim(p_user_agent_hash), ''), 128)
  );

  invitation_id := v_invitation.id;
  destination_url := v_destination;
  return next;
end;
$$;

revoke all on function public.redirect_invitation(text, text) from public, anon;
grant execute on function public.redirect_invitation(text, text) to authenticated;
