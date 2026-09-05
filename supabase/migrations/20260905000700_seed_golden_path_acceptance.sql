-- End-to-end golden-path acceptance session.
-- Purpose: prove normal PWA join -> natural Cron draw -> Resend prototype delivery
-- -> Rembayung invitation gate -> authenticated/audited redirect boundary.
-- UMAI destination remains a non-routable test URL for this acceptance.

insert into public.booking_sessions (
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
  status
)
values (
  'f0cc7c5e-5812-47c9-a405-aed71cb4eb73'::uuid,
  '[TEST] Golden Path — Invitation Gate',
  '2026-09-05 19:00:00+08'::timestamptz,
  '2026-09-05 10:15:00+08'::timestamptz,
  '2026-09-05 10:35:00+08'::timestamptz,
  '2026-09-05 10:37:00+08'::timestamptz,
  1,
  5,
  1,
  30,
  'https://example.invalid/umai-golden-path-acceptance',
  'published'::public.session_status
)
on conflict (id) do update set
  title = excluded.title,
  starts_at = excluded.starts_at,
  interest_opens_at = excluded.interest_opens_at,
  interest_closes_at = excluded.interest_closes_at,
  draw_starts_at = excluded.draw_starts_at,
  wave_size = excluded.wave_size,
  wave_interval_minutes = excluded.wave_interval_minutes,
  max_waves = excluded.max_waves,
  invitation_ttl_minutes = excluded.invitation_ttl_minutes,
  umai_url = excluded.umai_url,
  status = excluded.status;
