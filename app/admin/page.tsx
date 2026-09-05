'use client'

import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react'
import type { User } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'

type AdminSession = {
  session_id: string
  title: string
  starts_at: string
  interest_opens_at: string
  interest_closes_at: string
  draw_starts_at: string
  status: 'draft' | 'published' | 'closed' | 'completed' | 'cancelled'
  min_party_size: number
  max_party_size: number
  allocation_capacity_pax: number | null
  wave_size: number
  wave_interval_minutes: number
  max_waves: number
  invitation_ttl_minutes: number
  umai_url: string
  interest_total: number
  interest_active: number
  interest_selected: number
  wave_scheduled: number
  wave_completed: number
  wave_failed: number
  invitation_total: number
  delivery_pending: number
  delivery_sending: number
  delivery_sent: number
  delivery_failed: number
}

type SessionDraft = {
  title: string
  startsAt: string
  interestOpensAt: string
  interestClosesAt: string
  drawStartsAt: string
  minPartySize: number
  maxPartySize: number
  allocationCapacityPax: string
  waveSize: number
  waveIntervalMinutes: number
  maxWaves: number
  invitationTtlMinutes: number
  umaiUrl: string
}

const emptyDraft: SessionDraft = {
  title: '',
  startsAt: '',
  interestOpensAt: '',
  interestClosesAt: '',
  drawStartsAt: '',
  minPartySize: 3,
  maxPartySize: 8,
  allocationCapacityPax: '',
  waveSize: 25,
  waveIntervalMinutes: 12,
  maxWaves: 3,
  invitationTtlMinutes: 10,
  umaiUrl: ''
}

function formatKualaLumpur(value: string) {
  return new Intl.DateTimeFormat('ms-MY', {
    timeZone: 'Asia/Kuala_Lumpur',
    dateStyle: 'medium',
    timeStyle: 'short'
  }).format(new Date(value))
}

function toIso(value: string) {
  return new Date(value).toISOString()
}

export default function AdminPage() {
  const [user, setUser] = useState<User | null>(null)
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null)
  const [sessions, setSessions] = useState<AdminSession[]>([])
  const [draft, setDraft] = useState<SessionDraft>(emptyDraft)
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [isOnline, setIsOnline] = useState(true)

  const publishedCount = useMemo(
    () => sessions.filter((session) => session.status === 'published').length,
    [sessions]
  )

  const refresh = useCallback(async (currentUser: User | null) => {
    if (!currentUser) {
      setIsAdmin(null)
      setSessions([])
      return
    }

    const { data: adminData, error: adminError } = await supabase.rpc('is_platform_admin')

    if (adminError) {
      setIsAdmin(false)
      setMessage('Status admin tidak dapat disahkan sekarang.')
      return
    }

    const allowed = adminData === true
    setIsAdmin(allowed)

    if (!allowed) {
      setSessions([])
      return
    }

    const { data, error } = await supabase.rpc('admin_list_sessions')
    if (error) {
      setMessage(error.message)
      return
    }

    setSessions((data ?? []) as AdminSession[])
  }, [])

  useEffect(() => {
    setIsOnline(navigator.onLine)

    void supabase.auth.getUser().then(({ data }) => {
      const currentUser = data.user ?? null
      setUser(currentUser)
      void refresh(currentUser)
    })

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, session) => {
      const currentUser = session?.user ?? null
      setUser(currentUser)
      void refresh(currentUser)
    })

    const syncNetwork = () => {
      const online = navigator.onLine
      setIsOnline(online)
      if (online) void refresh(user)
    }

    window.addEventListener('online', syncNetwork)
    window.addEventListener('offline', syncNetwork)

    return () => {
      subscription.subscription.unsubscribe()
      window.removeEventListener('online', syncNetwork)
      window.removeEventListener('offline', syncNetwork)
    }
  }, [refresh, user])

  async function createSession(event: FormEvent) {
    event.preventDefault()
    if (!user || !isAdmin || !isOnline) return

    setBusy(true)
    setMessage(null)

    try {
      const capacity = draft.allocationCapacityPax.trim()
      const { error } = await supabase.rpc('admin_create_session', {
        p_title: draft.title,
        p_starts_at: toIso(draft.startsAt),
        p_interest_opens_at: toIso(draft.interestOpensAt),
        p_interest_closes_at: toIso(draft.interestClosesAt),
        p_draw_starts_at: toIso(draft.drawStartsAt),
        p_min_party_size: draft.minPartySize,
        p_max_party_size: draft.maxPartySize,
        p_allocation_capacity_pax: capacity ? Number(capacity) : null,
        p_wave_size: draft.waveSize,
        p_wave_interval_minutes: draft.waveIntervalMinutes,
        p_max_waves: draft.maxWaves,
        p_invitation_ttl_minutes: draft.invitationTtlMinutes,
        p_umai_url: draft.umaiUrl
      })

      if (error) {
        setMessage(error.message)
        return
      }

      setDraft(emptyDraft)
      setMessage('Sesi draft berjaya dicipta. Semak konfigurasi sebelum publish.')
      await refresh(user)
    } catch {
      setMessage('Tarikh atau konfigurasi sesi tidak sah.')
    } finally {
      setBusy(false)
    }
  }

  async function publishSession(sessionId: string) {
    if (!user || !isAdmin || !isOnline) return

    setBusy(true)
    setMessage(null)
    const { error } = await supabase.rpc('admin_publish_session', { p_session_id: sessionId })
    setBusy(false)

    if (error) {
      setMessage(error.message)
      return
    }

    setMessage('Sesi telah dipublish. Scheduler akan materialize wave mengikut authority database.')
    await refresh(user)
  }

  return (
    <main className="shell">
      <section className="hero">
        <p className="eyebrow">Rembayung Access · Admin</p>
        <h1>Operasi sesi</h1>
        <p className="lead">
          Cipta dan publish sesi fair-access, tetapkan party-size serta pax budget, kemudian pantau pool,
          wave, invitation dan delivery. Admin tidak memilih pemenang; PostgreSQL kekal winner authority.
        </p>
      </section>

      {!isOnline && (
        <div className="status offline" role="status">
          Offline — admin configuration dan operational state memerlukan sambungan.
        </div>
      )}

      {message && <div className="status">{message}</div>}

      {!user ? (
        <section className="card stack">
          <h2>Log masuk dahulu</h2>
          <p className="muted">Gunakan akaun Rembayung yang telah diberikan platform-admin membership.</p>
          <a href="/">Kembali ke halaman utama untuk log masuk</a>
        </section>
      ) : isAdmin === null ? (
        <section className="card muted">Mengesahkan akses admin…</section>
      ) : !isAdmin ? (
        <section className="card stack">
          <h2>Akses admin belum diberikan</h2>
          <p className="muted">
            Akaun ini authenticated tetapi bukan platform admin. Membership hanya boleh diberikan melalui
            service-role authority; browser tidak boleh menaikkan privilege sendiri.
          </p>
          <a href="/">Kembali ke Rembayung Access</a>
        </section>
      ) : (
        <>
          <section className="card stack">
            <div className="row" style={{ justifyContent: 'space-between' }}>
              <div>
                <strong>{user.email}</strong>
                <div className="muted">Platform admin · {publishedCount} sesi published</div>
              </div>
              <button className="secondary" disabled={busy || !isOnline} onClick={() => refresh(user)}>
                Refresh
              </button>
            </div>
          </section>

          <section className="card stack">
            <div>
              <p className="eyebrow">Session configuration</p>
              <h2>Cipta sesi draft</h2>
            </div>

            <form className="stack" onSubmit={createSession}>
              <label className="stack">
                <span className="muted">Nama sesi</span>
                <input
                  value={draft.title}
                  onChange={(event) => setDraft((current) => ({ ...current, title: event.target.value }))}
                  placeholder="Contoh: Sabtu · Dinner 7:30 malam"
                  required
                />
              </label>

              <label className="stack">
                <span className="muted">Sesi bermula</span>
                <input
                  type="datetime-local"
                  value={draft.startsAt}
                  onChange={(event) => setDraft((current) => ({ ...current, startsAt: event.target.value }))}
                  required
                />
              </label>

              <label className="stack">
                <span className="muted">Interest pool buka</span>
                <input
                  type="datetime-local"
                  value={draft.interestOpensAt}
                  onChange={(event) => setDraft((current) => ({ ...current, interestOpensAt: event.target.value }))}
                  required
                />
              </label>

              <label className="stack">
                <span className="muted">Interest pool tutup</span>
                <input
                  type="datetime-local"
                  value={draft.interestClosesAt}
                  onChange={(event) => setDraft((current) => ({ ...current, interestClosesAt: event.target.value }))}
                  required
                />
              </label>

              <label className="stack">
                <span className="muted">Draw bermula</span>
                <input
                  type="datetime-local"
                  value={draft.drawStartsAt}
                  onChange={(event) => setDraft((current) => ({ ...current, drawStartsAt: event.target.value }))}
                  required
                />
              </label>

              <div className="row">
                <label className="stack" style={{ flex: '1 1 150px' }}>
                  <span className="muted">Min party</span>
                  <input
                    type="number"
                    min={1}
                    max={100}
                    value={draft.minPartySize}
                    onChange={(event) => setDraft((current) => ({ ...current, minPartySize: Number(event.target.value) }))}
                    required
                  />
                </label>
                <label className="stack" style={{ flex: '1 1 150px' }}>
                  <span className="muted">Max party</span>
                  <input
                    type="number"
                    min={1}
                    max={100}
                    value={draft.maxPartySize}
                    onChange={(event) => setDraft((current) => ({ ...current, maxPartySize: Number(event.target.value) }))}
                    required
                  />
                </label>
              </div>

              <label className="stack">
                <span className="muted">Allocation budget (pax)</span>
                <input
                  type="number"
                  min={1}
                  value={draft.allocationCapacityPax}
                  onChange={(event) => setDraft((current) => ({ ...current, allocationCapacityPax: event.target.value }))}
                  placeholder="Contoh: 120"
                />
              </label>

              <div className="row">
                <label className="stack" style={{ flex: '1 1 140px' }}>
                  <span className="muted">Wave size</span>
                  <input
                    type="number"
                    min={1}
                    value={draft.waveSize}
                    onChange={(event) => setDraft((current) => ({ ...current, waveSize: Number(event.target.value) }))}
                    required
                  />
                </label>
                <label className="stack" style={{ flex: '1 1 140px' }}>
                  <span className="muted">Wave interval (min)</span>
                  <input
                    type="number"
                    min={1}
                    max={120}
                    value={draft.waveIntervalMinutes}
                    onChange={(event) => setDraft((current) => ({ ...current, waveIntervalMinutes: Number(event.target.value) }))}
                    required
                  />
                </label>
              </div>

              <div className="row">
                <label className="stack" style={{ flex: '1 1 140px' }}>
                  <span className="muted">Max waves</span>
                  <input
                    type="number"
                    min={1}
                    max={20}
                    value={draft.maxWaves}
                    onChange={(event) => setDraft((current) => ({ ...current, maxWaves: Number(event.target.value) }))}
                    required
                  />
                </label>
                <label className="stack" style={{ flex: '1 1 140px' }}>
                  <span className="muted">Invitation TTL (min)</span>
                  <input
                    type="number"
                    min={1}
                    max={120}
                    value={draft.invitationTtlMinutes}
                    onChange={(event) => setDraft((current) => ({ ...current, invitationTtlMinutes: Number(event.target.value) }))}
                    required
                  />
                </label>
              </div>

              <label className="stack">
                <span className="muted">UMAI downstream URL</span>
                <input
                  type="url"
                  value={draft.umaiUrl}
                  onChange={(event) => setDraft((current) => ({ ...current, umaiUrl: event.target.value }))}
                  placeholder="https://..."
                  required
                />
              </label>

              <button disabled={busy || !isOnline} type="submit">
                {busy ? 'Menyimpan…' : 'Cipta draft'}
              </button>
            </form>
          </section>

          <section>
            <h2>Session operations</h2>
            <div className="sessionGrid">
              {sessions.length === 0 && <div className="card muted">Belum ada sesi.</div>}

              {sessions.map((session) => (
                <article className="card stack" key={session.session_id}>
                  <div>
                    <p className="eyebrow">{session.status}</p>
                    <h3 className="sessionTitle">{session.title}</h3>
                  </div>

                  <div className="sessionMeta">
                    <span>Sesi: {formatKualaLumpur(session.starts_at)}</span>
                    <span>Pool tutup: {formatKualaLumpur(session.interest_closes_at)}</span>
                    <span>Draw: {formatKualaLumpur(session.draw_starts_at)}</span>
                    <span>Party: {session.min_party_size}–{session.max_party_size} pax</span>
                    <span>Allocation budget: {session.allocation_capacity_pax ?? 'tanpa had pax khusus'}</span>
                    <span>Wave: {session.wave_size} orang · {session.wave_interval_minutes} min · max {session.max_waves}</span>
                  </div>

                  <div className="status">
                    Pool {session.interest_active} active / {session.interest_selected} selected / {session.interest_total} total
                  </div>
                  <div className="status">
                    Waves {session.wave_scheduled} scheduled / {session.wave_completed} completed / {session.wave_failed} failed
                  </div>
                  <div className="status">
                    Invitations {session.invitation_total} · Email {session.delivery_sent} sent / {session.delivery_pending} pending / {session.delivery_sending} sending / {session.delivery_failed} failed
                  </div>

                  {session.status === 'draft' && (
                    <button disabled={busy || !isOnline} onClick={() => publishSession(session.session_id)}>
                      Publish sesi
                    </button>
                  )}
                </article>
              ))}
            </div>
          </section>
        </>
      )}
    </main>
  )
}
