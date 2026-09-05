-- Slice D production acceptance harness.
-- This migration creates a temporary fixture, executes the real invitation RPCs,
-- asserts the security/state boundaries, then removes every fixture row before commit.
-- Any failed assertion aborts and rolls back the migration.

do $$
declare
  v_owner_id uuid;
  v_wrong_owner_id uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_interest_id uuid := gen_random_uuid();
  v_wave_id uuid := gen_random_uuid();
  v_invitation_id uuid := gen_random_uuid();
  v_token text := 'slice-d-runtime-token-7f55e73f8e0f4f19a2ecad7a9b4178c8';
  v_destination text := 'https://example.com/umai-slice-d-runtime';
  v_open record;
  v_redirect record;
  v_count integer;
  v_status public.invitation_status;
begin
  select u.id
  into v_owner_id
  from auth.users u
  order by u.created_at
  limit 1;

  if v_owner_id is null then
    raise exception 'Slice D runtime acceptance requires at least one auth user';
  end if;

  insert into public.booking_sessions(
    id, title, starts_at, interest_opens_at, interest_closes_at, draw_starts_at,
    wave_size, wave_interval_minutes, max_waves, invitation_ttl_minutes, umai_url, status
  ) values (
    v_session_id,
    '[TEST] Slice D — Transactional Invitation Gate',
    now() + interval '1 day',
    now() - interval '2 hours',
    now() - interval '1 hour',
    now() - interval '30 minutes',
    1, 5, 1, 30, v_destination, 'published'
  );

  insert into public.interests(
    id, user_id, session_id, party_size, status, joined_at, selected_at
  ) values (
    v_interest_id, v_owner_id, v_session_id, 2, 'selected',
    now() - interval '90 minutes', now() - interval '20 minutes'
  );

  insert into public.draw_waves(
    id, session_id, wave_no, scheduled_at, processed_at, status, selected_count
  ) values (
    v_wave_id, v_session_id, 1, now() - interval '30 minutes',
    now() - interval '20 minutes', 'completed', 1
  );

  insert into public.invitations(
    id, wave_id, interest_id, user_id, session_id, token_hash, status, issued_at, expires_at
  ) values (
    v_invitation_id,
    v_wave_id,
    v_interest_id,
    v_owner_id,
    v_session_id,
    encode(extensions.digest(v_token, 'sha256'), 'hex'),
    'issued',
    now() - interval '5 minutes',
    now() + interval '20 minutes'
  );

  -- Valid owner: issued -> opened.
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);
  select * into v_open from public.open_invitation(v_token);

  if v_open.invitation_id is distinct from v_invitation_id then
    raise exception 'valid owner could not open invitation';
  end if;

  if v_open.invitation_status <> 'opened' then
    raise exception 'expected opened status, got %', v_open.invitation_status;
  end if;

  -- Wrong owner: same token must resolve to nothing.
  perform set_config('request.jwt.claim.sub', v_wrong_owner_id::text, true);
  select count(*) into v_count from public.open_invitation(v_token);

  if v_count <> 0 then
    raise exception 'wrong owner unexpectedly resolved invitation';
  end if;

  -- Valid redirect: canonical DB destination + audit.
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);
  select * into v_redirect
  from public.redirect_invitation(v_token, repeat('a', 64));

  if v_redirect.invitation_id is distinct from v_invitation_id
    or v_redirect.destination_url is distinct from v_destination then
    raise exception 'valid redirect did not return canonical destination';
  end if;

  select count(*) into v_count
  from public.redirect_audits a
  where a.invitation_id = v_invitation_id;

  if v_count <> 1 then
    raise exception 'expected one redirect audit after first redirect, got %', v_count;
  end if;

  -- Repeated redirect: no new entitlement; same destination; second action is auditable.
  select * into v_redirect
  from public.redirect_invitation(v_token, repeat('b', 64));

  if v_redirect.destination_url is distinct from v_destination then
    raise exception 'repeat redirect changed destination';
  end if;

  select count(*) into v_count
  from public.redirect_audits a
  where a.invitation_id = v_invitation_id;

  if v_count <> 2 then
    raise exception 'expected two redirect audits after repeat redirect, got %', v_count;
  end if;

  select i.status into v_status
  from public.invitations i
  where i.id = v_invitation_id;

  if v_status <> 'redirected' then
    raise exception 'expected redirected invitation state, got %', v_status;
  end if;

  -- Expired owner token: visible as expired, never returns UMAI destination.
  update public.invitations
  set expires_at = now() - interval '1 minute'
  where id = v_invitation_id;

  select * into v_open from public.open_invitation(v_token);

  if v_open.invitation_status <> 'expired' then
    raise exception 'expected expired state after expiry, got %', v_open.invitation_status;
  end if;

  select count(*) into v_count
  from public.redirect_invitation(v_token, repeat('c', 64));

  if v_count <> 0 then
    raise exception 'expired invitation unexpectedly returned redirect destination';
  end if;

  select count(*) into v_count
  from public.redirect_audits a
  where a.invitation_id = v_invitation_id;

  if v_count <> 2 then
    raise exception 'expired redirect attempt should not create audit; got %', v_count;
  end if;

  -- Leave no runtime fixture behind.
  delete from public.redirect_audits where invitation_id = v_invitation_id;
  delete from public.invitations where id = v_invitation_id;
  delete from public.draw_waves where id = v_wave_id;
  delete from public.interests where id = v_interest_id;
  delete from public.booking_sessions where id = v_session_id;

  perform set_config('request.jwt.claim.sub', '', true);

  raise notice 'PASS: Slice D valid owner, wrong owner, repeated redirect and expiry boundaries verified';
end;
$$;
