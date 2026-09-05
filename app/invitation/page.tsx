'use client'

import { FormEvent, useCallback, useEffect, useState } from 'react'
import type { User } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'

type InvitationView = {
  invitation_id: string
  session_id: string
  session_title: string
  session_starts_at: string
  party_size: number
  invitation_status: 'issued' | 'opened' | 'redirected' | 'expired' | 'revoked'
  expires_at: string
}

function formatKualaLumpur(value: string) {
  return new Intl.DateTimeFormat('ms-MY', {
    timeZone: 'Asia/Kuala_Lumpur',
    dateStyle: 'medium',
    timeStyle: 'short'
  }).format(new Date(value))
}

async function userAgentHash() {
  const bytes = new TextEncoder().encode(navigator.userAgent)
  const digest = await crypto.subtle.digest('SHA-256', bytes)
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('')
}

export default function InvitationPage() {
  const [token, setToken] = useState<string | null>(null)
  const [user, setUser] = useState<User | null>(null)
  const [invitation, setInvitation] = useState<InvitationView | null>(null)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState<string | null>('Memeriksa jemputan…')
  const [isOnline, setIsOnline] = useState(true)

  const resolveInvitation = useCallback(async (currentToken: string, currentUser: User) => {
    setBusy(true)
    setMessage('Mengesahkan pemilik dan tempoh sah jemputan…')

    const { data, error } = await supabase.rpc('open_invitation', { p_token: currentToken })
    setBusy(false)

    if (error) {
      setInvitation(null)
      setMessage('Jemputan tidak dapat disahkan sekarang. Cuba semula apabila sambungan stabil.')
      return
    }

    const row = (data?.[0] ?? null) as InvitationView | null
    setInvitation(row)

    if (!row) {
      setMessage(`Jemputan ini tidak sepadan dengan akaun ${currentUser.email ?? 'yang sedang digunakan'}.`)
      return
    }

    if (row.invitation_status === 'expired') {
      setMessage('Jemputan ini telah tamat tempoh.')
      return
    }

    if (row.invitation_status === 'revoked') {
      setMessage('Jemputan ini tidak lagi aktif.')
      return
    }

    setMessage('Jemputan sah. Anda boleh teruskan ke UMAI untuk membuat tempahan sebenar.')
  }, [])

  useEffect(() => {
    const currentToken = new URLSearchParams(window.location.search).get('token')
    setToken(currentToken)
    setIsOnline(navigator.onLine)

    if (!currentToken) {
      setMessage('Pautan jemputan tidak lengkap.')
    }

    void supabase.auth.getUser().then(({ data }) => setUser(data.user ?? null))

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null)
    })

    const syncNetworkState = () => setIsOnline(navigator.onLine)
    window.addEventListener('online', syncNetworkState)
    window.addEventListener('offline', syncNetworkState)

    return () => {
      subscription.subscription.unsubscribe()
      window.removeEventListener('online', syncNetworkState)
      window.removeEventListener('offline', syncNetworkState)
    }
  }, [])

  useEffect(() => {
    if (token && user && isOnline) {
      void resolveInvitation(token, user)
    }
  }, [token, user, isOnline, resolveInvitation])

  async function signIn(event: FormEvent) {
    event.preventDefault()
    if (!isOnline) return
    setBusy(true)
    setMessage(null)
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    setBusy(false)
    if (error) setMessage(error.message)
  }

  async function continueToUmai() {
    if (!token || !user || !isOnline) return
    setBusy(true)
    setMessage('Mengesahkan jemputan sebelum meneruskan…')

    try {
      const hash = await userAgentHash()
      const { data, error } = await supabase.rpc('redirect_invitation', {
        p_token: token,
        p_user_agent_hash: hash
      })

      if (error) {
        setMessage('Jemputan tidak dapat diteruskan. Sila cuba semula.')
        return
      }

      const row = (data?.[0] ?? null) as { invitation_id: string; destination_url: string } | null
      if (!row?.destination_url) {
        setMessage('Jemputan telah tamat tempoh, dibatalkan, atau tidak sah untuk akaun ini.')
        await resolveInvitation(token, user)
        return
      }

      window.location.assign(row.destination_url)
    } finally {
      setBusy(false)
    }
  }

  const actionable = invitation && ['opened', 'redirected'].includes(invitation.invitation_status)

  return (
    <main className="shell">
      <section className="hero">
        <p className="eyebrow">Rembayung Access</p>
        <h1>Jemputan anda</h1>
        <p className="lead">
          Rembayung mengesahkan pemilik dan tempoh sah jemputan sebelum anda diteruskan ke UMAI.
          Jemputan ini bukan tempahan.
        </p>
      </section>

      {!isOnline && (
        <div className="status offline" role="status">
          Offline — pengesahan jemputan dan redirect memerlukan sambungan.
        </div>
      )}

      {message && <div className="status">{message}</div>}

      {!token ? (
        <section className="card stack">
          <h2>Pautan tidak sah</h2>
          <p className="muted">Buka pautan asal yang dihantar melalui jemputan Rembayung.</p>
          <a href="/">Kembali ke Rembayung Access</a>
        </section>
      ) : !user ? (
        <section className="card stack" aria-label="Log masuk untuk membuka jemputan">
          <h2>Log masuk untuk membuka jemputan</h2>
          <p className="muted">Gunakan akaun yang menerima jemputan ini.</p>
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
            <button disabled={busy || !isOnline} type="submit">Log masuk dan semak jemputan</button>
          </form>
        </section>
      ) : invitation ? (
        <section className="card stack">
          <div>
            <p className="eyebrow">Sesi dipilih</p>
            <h2>{invitation.session_title}</h2>
          </div>
          <div className="sessionMeta">
            <span>Sesi: {formatKualaLumpur(invitation.session_starts_at)}</span>
            <span>Bilangan tetamu: {invitation.party_size} orang</span>
            <span>Jemputan sah sehingga: {formatKualaLumpur(invitation.expires_at)}</span>
          </div>

          {actionable ? (
            <button disabled={busy || !isOnline} onClick={continueToUmai}>
              {busy ? 'Mengesahkan…' : 'Teruskan ke UMAI'}
            </button>
          ) : (
            <a href="/">Kembali ke Rembayung Access</a>
          )}
        </section>
      ) : (
        <section className="card stack">
          <h2>Jemputan tidak tersedia</h2>
          <p className="muted">Pastikan anda menggunakan akaun penerima jemputan.</p>
          <a href="/">Kembali ke Rembayung Access</a>
        </section>
      )}
    </main>
  )
}
