'use client'

import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react'
import type { User } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'

type BookingSession = {
  id: string
  title: string
  starts_at: string
  interest_opens_at: string
  interest_closes_at: string
  draw_starts_at: string
  status: 'published'
}

type Interest = {
  id: string
  session_id: string
  party_size: number
  status: 'active' | 'selected' | 'cancelled' | 'closed'
}

function formatKualaLumpur(value: string) {
  return new Intl.DateTimeFormat('ms-MY', {
    timeZone: 'Asia/Kuala_Lumpur',
    dateStyle: 'medium',
    timeStyle: 'short'
  }).format(new Date(value))
}

export default function HomePage() {
  const [user, setUser] = useState<User | null>(null)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [sessions, setSessions] = useState<BookingSession[]>([])
  const [interests, setInterests] = useState<Interest[]>([])
  const [partySizes, setPartySizes] = useState<Record<string, number>>({})
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [isOnline, setIsOnline] = useState(true)

  const interestBySession = useMemo(
    () => new Map(interests.map((interest) => [interest.session_id, interest])),
    [interests]
  )

  const refresh = useCallback(async () => {
    if (!user) {
      setSessions([])
      setInterests([])
      return
    }

    const [{ data: sessionRows, error: sessionError }, { data: interestRows, error: interestError }] =
      await Promise.all([
        supabase
          .from('booking_sessions')
          .select('id,title,starts_at,interest_opens_at,interest_closes_at,draw_starts_at,status')
          .eq('status', 'published')
          .order('starts_at', { ascending: true }),
        supabase
          .from('interests')
          .select('id,session_id,party_size,status')
          .order('joined_at', { ascending: false })
      ])

    if (sessionError || interestError) {
      setMessage(sessionError?.message ?? interestError?.message ?? 'Tidak dapat memuatkan data.')
      return
    }

    setSessions((sessionRows ?? []) as BookingSession[])
    setInterests((interestRows ?? []) as Interest[])
  }, [user])

  useEffect(() => {
    void supabase.auth.getUser().then(({ data }) => setUser(data.user ?? null))

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null)
    })

    return () => subscription.subscription.unsubscribe()
  }, [])

  useEffect(() => {
    void refresh()
  }, [refresh])

  useEffect(() => {
    const syncNetworkState = () => {
      const online = navigator.onLine
      setIsOnline(online)
      if (online) void refresh()
    }

    syncNetworkState()
    window.addEventListener('online', syncNetworkState)
    window.addEventListener('offline', syncNetworkState)

    return () => {
      window.removeEventListener('online', syncNetworkState)
      window.removeEventListener('offline', syncNetworkState)
    }
  }, [refresh])

  async function signIn(event: FormEvent) {
    event.preventDefault()
    if (!isOnline) return
    setBusy(true)
    setMessage(null)
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    setBusy(false)
    setMessage(error ? error.message : 'Log masuk berjaya.')
  }

  async function signUp() {
    if (!isOnline) return
    setBusy(true)
    setMessage(null)
    const { error } = await supabase.auth.signUp({ email, password })
    setBusy(false)
    setMessage(error ? error.message : 'Akaun didaftarkan. Semak e-mel jika pengesahan diperlukan.')
  }

  async function signOut() {
    if (!isOnline) return
    setBusy(true)
    await supabase.auth.signOut()
    setBusy(false)
    setMessage('Anda telah log keluar.')
  }

  async function joinInterest(sessionId: string) {
    if (!isOnline) return
    setBusy(true)
    setMessage(null)
    const partySize = partySizes[sessionId] ?? 2
    const { error } = await supabase.rpc('join_interest', {
      p_session_id: sessionId,
      p_party_size: partySize
    })
    setBusy(false)
    setMessage(error ? error.message : 'Minat anda telah didaftarkan untuk sesi ini.')
    if (!error) await refresh()
  }

  async function cancelInterest(interestId: string) {
    if (!isOnline) return
    setBusy(true)
    setMessage(null)
    const { error } = await supabase.rpc('cancel_interest', { p_interest_id: interestId })
    setBusy(false)
    setMessage(error ? error.message : 'Penyertaan minat dibatalkan.')
    if (!error) await refresh()
  }

  return (
    <main className="shell">
      <section className="hero">
        <p className="eyebrow">Rembayung Access</p>
        <h1>Daftar minat. Bukan berlumba klik.</h1>
        <p className="lead">
          Sertai interest pool untuk sesi yang tersedia. Pemilihan akses dibuat secara rawak mengikut
          wave. Jemputan bukan tempahan; UMAI kekal sebagai saluran tempahan sebenar.
        </p>
      </section>

      {!isOnline && (
        <div className="status offline" role="status">
          Offline — anda boleh melihat app shell, tetapi status dan tindakan booking memerlukan sambungan.
        </div>
      )}

      {message && <div className="status">{message}</div>}

      {!user ? (
        <section className="card stack" aria-label="Log masuk">
          <h2>Masuk atau daftar</h2>
          <form className="stack" onSubmit={signIn}>
            <input
              type="email"
              autoComplete="email"
              placeholder="E-mel"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              required
            />
            <input
              type="password"
              autoComplete="current-password"
              placeholder="Kata laluan"
              minLength={8}
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
            />
            <div className="row">
              <button disabled={busy || !isOnline} type="submit">Log masuk</button>
              <button disabled={busy || !isOnline} className="secondary" type="button" onClick={signUp}>
                Daftar akaun
              </button>
            </div>
          </form>
        </section>
      ) : (
        <>
          <section className="card">
            <div className="row" style={{ justifyContent: 'space-between' }}>
              <div>
                <strong>{user.email}</strong>
                <div className="muted">Satu akaun untuk semua sesi Rembayung Access.</div>
              </div>
              <button disabled={busy || !isOnline} className="secondary" onClick={signOut}>Log keluar</button>
            </div>
          </section>

          <section>
            <h2>Sesi akan datang</h2>
            <div className="sessionGrid">
              {sessions.length === 0 && (
                <div className="card muted">Belum ada sesi yang diterbitkan untuk interest pool.</div>
              )}

              {sessions.map((session) => {
                const now = Date.now()
                const opensAt = new Date(session.interest_opens_at).getTime()
                const closesAt = new Date(session.interest_closes_at).getTime()
                const isOpen = now >= opensAt && now <= closesAt
                const interest = interestBySession.get(session.id)
                const active = interest?.status === 'active'

                return (
                  <article className="card" key={session.id}>
                    <h3 className="sessionTitle">{session.title}</h3>
                    <div className="sessionMeta">
                      <span>Sesi: {formatKualaLumpur(session.starts_at)}</span>
                      <span>Interest pool tutup: {formatKualaLumpur(session.interest_closes_at)}</span>
                      <span>Draw bermula: {formatKualaLumpur(session.draw_starts_at)}</span>
                    </div>

                    {interest?.status === 'selected' ? (
                      <div className="status">Anda telah dipilih. Jemputan akan dikendalikan melalui saluran invitation.</div>
                    ) : active ? (
                      <div className="row">
                        <span className="status">Dalam interest pool · {interest.party_size} orang</span>
                        <button disabled={busy || !isOnline} className="secondary" onClick={() => cancelInterest(interest.id)}>
                          Batalkan minat
                        </button>
                      </div>
                    ) : (
                      <div className="row">
                        <label>
                          <span className="muted">Bilangan tetamu</span>
                          <select
                            value={partySizes[session.id] ?? 2}
                            onChange={(event) =>
                              setPartySizes((current) => ({ ...current, [session.id]: Number(event.target.value) }))
                            }
                          >
                            {[2, 3, 4, 5, 6, 7, 8].map((size) => (
                              <option key={size} value={size}>{size} orang</option>
                            ))}
                          </select>
                        </label>
                        <button disabled={busy || !isOnline || !isOpen} onClick={() => joinInterest(session.id)}>
                          {!isOnline ? 'Perlu online' : isOpen ? 'Daftar minat' : now < opensAt ? 'Belum dibuka' : 'Interest pool ditutup'}
                        </button>
                      </div>
                    )}
                  </article>
                )
              })}
            </div>
          </section>
        </>
      )}
    </main>
  )
}
