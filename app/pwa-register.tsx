'use client'

import { useEffect, useState } from 'react'

type InstallPromptEvent = Event & {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed'; platform: string }>
}

type RelatedApp = {
  platform?: string
  url?: string
  id?: string
}

type NavigatorWithRelatedApps = Navigator & {
  standalone?: boolean
  getInstalledRelatedApps?: () => Promise<RelatedApp[]>
}

type InstallState = 'idle' | 'checking' | 'shortcut-or-pending'

function isStandalone() {
  if (typeof window === 'undefined' || typeof navigator === 'undefined') return false
  return window.matchMedia('(display-mode: standalone)').matches ||
    (navigator as NavigatorWithRelatedApps).standalone === true
}

function isAppleMobile() {
  const ua = navigator.userAgent
  return /iPhone|iPad|iPod/i.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
}

function isAndroidMobile() {
  return /Android/i.test(navigator.userAgent)
}

async function hasFullInstalledWebApp() {
  if (isStandalone()) return true

  const nav = navigator as NavigatorWithRelatedApps
  if (!nav.getInstalledRelatedApps) return false

  try {
    const apps = await nav.getInstalledRelatedApps()
    return apps.some((app) =>
      app.platform === 'webapp' &&
      typeof app.url === 'string' &&
      app.url.includes('/manifest.webmanifest')
    )
  } catch {
    return false
  }
}

const DISMISS_KEY = 'rembayung-install-prompt-dismissed-v3'

export function PwaRegister() {
  const [installPrompt, setInstallPrompt] = useState<InstallPromptEvent | null>(null)
  const [showIosHelp, setShowIosHelp] = useState(false)
  const [visible, setVisible] = useState(false)
  const [installState, setInstallState] = useState<InstallState>('idle')

  useEffect(() => {
    if ('serviceWorker' in navigator) {
      void navigator.serviceWorker.register('/sw.js', { scope: '/' }).catch((error) => {
        console.error('PWA service worker registration failed', error)
      })
    }

    if (isStandalone()) return
    if (sessionStorage.getItem(DISMISS_KEY) === '1') return

    let cancelled = false

    const establishInstallState = async () => {
      const installed = await hasFullInstalledWebApp()
      if (cancelled || installed) return

      if (isAppleMobile()) {
        setShowIosHelp(true)
        setVisible(true)
      } else if (isAndroidMobile()) {
        setShowIosHelp(false)
        setVisible(true)
      }
    }

    void establishInstallState()

    const handleBeforeInstallPrompt = (event: Event) => {
      event.preventDefault()
      setInstallPrompt(event as InstallPromptEvent)
      setShowIosHelp(false)
      setInstallState('idle')
      setVisible(true)
    }

    const handleInstalled = () => {
      setInstallPrompt(null)
      setInstallState('checking')
      window.setTimeout(() => {
        void verifyInstallAfterBrowserFlow()
      }, 1800)
    }

    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
    window.addEventListener('appinstalled', handleInstalled)

    return () => {
      cancelled = true
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
      window.removeEventListener('appinstalled', handleInstalled)
    }
  }, [])

  async function verifyInstallAfterBrowserFlow() {
    setInstallState('checking')

    if (await hasFullInstalledWebApp()) {
      setVisible(false)
      setInstallPrompt(null)
      setInstallState('idle')
      sessionStorage.removeItem(DISMISS_KEY)
      return true
    }

    await new Promise((resolve) => window.setTimeout(resolve, 3200))

    if (await hasFullInstalledWebApp()) {
      setVisible(false)
      setInstallPrompt(null)
      setInstallState('idle')
      sessionStorage.removeItem(DISMISS_KEY)
      return true
    }

    setInstallPrompt(null)
    setInstallState('shortcut-or-pending')
    setVisible(true)
    return false
  }

  async function installAndroid() {
    if (!installPrompt) return

    await installPrompt.prompt()
    const choice = await installPrompt.userChoice

    if (choice.outcome === 'accepted') {
      await verifyInstallAfterBrowserFlow()
    }
  }

  function dismiss() {
    sessionStorage.setItem(DISMISS_KEY, '1')
    setVisible(false)
  }

  if (!visible || isStandalone()) return null

  return (
    <div className="installPromptBackdrop" role="presentation">
      <section className="installPromptCard" role="dialog" aria-modal="true" aria-labelledby="install-title">
        <div className="installPromptIcon" aria-hidden="true">R</div>
        <div>
          <p className="installPromptEyebrow">Rembayung Access</p>
          <h2 id="install-title" className="installPromptTitle">
            {showIosHelp ? 'Tambah ke Home Screen' : 'Install app Rembayung'}
          </h2>

          {showIosHelp ? (
            <p className="installPromptCopy">
              Di iPhone: tekan <strong>Share</strong>, kemudian pilih <strong>Add to Home Screen</strong>.
            </p>
          ) : installState === 'checking' ? (
            <p className="installPromptCopy">
              Sedang semak sama ada Rembayung dipasang sebagai app penuh pada Android…
            </p>
          ) : installState === 'shortcut-or-pending' ? (
            <p className="installPromptCopy">
              Pemasangan app penuh belum dapat disahkan. Jika ikon Rembayung mempunyai badge Chrome, itu masih shortcut. Anda boleh semak semula selepas beberapa saat.
            </p>
          ) : installPrompt ? (
            <p className="installPromptCopy">
              Pasang app untuk buka lebih cepat dalam paparan standalone, tanpa perlu cari laman ini semula.
            </p>
          ) : (
            <p className="installPromptCopy">
              Untuk pasang di Android, buka menu Chrome <strong>⋮</strong> dan pilih <strong>Install app</strong>. Jika Chrome hanya menawarkan Add to Home screen, ia mungkin menghasilkan shortcut sahaja.
            </p>
          )}
        </div>

        <div className="installPromptActions">
          {!showIosHelp && installPrompt && installState === 'idle' && (
            <button type="button" className="installPromptPrimary" onClick={installAndroid}>
              Install app
            </button>
          )}

          {!showIosHelp && installState === 'shortcut-or-pending' && (
            <button type="button" className="installPromptPrimary" onClick={() => void verifyInstallAfterBrowserFlow()}>
              Semak pemasangan
            </button>
          )}

          <button type="button" className="installPromptLater" onClick={dismiss}>
            Nanti
          </button>
        </div>
      </section>
    </div>
  )
}
