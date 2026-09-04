'use client'

import { useEffect, useState } from 'react'

type InstallPromptEvent = Event & {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed'; platform: string }>
}

function isStandalone() {
  if (typeof window === 'undefined' || typeof navigator === 'undefined') return false
  return window.matchMedia('(display-mode: standalone)').matches ||
    (navigator as Navigator & { standalone?: boolean }).standalone === true
}

function isAppleMobile() {
  const ua = navigator.userAgent
  return /iPhone|iPad|iPod/i.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
}

function isAndroidMobile() {
  return /Android/i.test(navigator.userAgent)
}

const DISMISS_KEY = 'rembayung-install-prompt-dismissed-v2'

export function PwaRegister() {
  const [installPrompt, setInstallPrompt] = useState<InstallPromptEvent | null>(null)
  const [showIosHelp, setShowIosHelp] = useState(false)
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    if ('serviceWorker' in navigator) {
      void navigator.serviceWorker.register('/sw.js', { scope: '/' }).catch((error) => {
        console.error('PWA service worker registration failed', error)
      })
    }

    if (isStandalone()) return
    if (sessionStorage.getItem(DISMISS_KEY) === '1') return

    if (isAppleMobile()) {
      setShowIosHelp(true)
      setVisible(true)
    } else if (isAndroidMobile()) {
      // Show the in-app install surface immediately on Android. Chromium may emit
      // beforeinstallprompt later (or not at all if it has already consumed/suppressed it).
      setShowIosHelp(false)
      setVisible(true)
    }

    const handleBeforeInstallPrompt = (event: Event) => {
      event.preventDefault()
      setInstallPrompt(event as InstallPromptEvent)
      setShowIosHelp(false)
      setVisible(true)
    }

    const handleInstalled = () => {
      setVisible(false)
      setInstallPrompt(null)
      sessionStorage.removeItem(DISMISS_KEY)
    }

    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
    window.addEventListener('appinstalled', handleInstalled)

    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
      window.removeEventListener('appinstalled', handleInstalled)
    }
  }, [])

  async function installAndroid() {
    if (!installPrompt) return
    await installPrompt.prompt()
    const choice = await installPrompt.userChoice
    if (choice.outcome === 'accepted') {
      setVisible(false)
      setInstallPrompt(null)
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
          ) : installPrompt ? (
            <p className="installPromptCopy">
              Pasang app untuk buka lebih cepat dalam paparan standalone, tanpa perlu cari laman ini semula.
            </p>
          ) : (
            <p className="installPromptCopy">
              Untuk pasang di Android, buka menu Chrome <strong>⋮</strong> dan pilih <strong>Install app</strong>. Jika butang automatik tersedia, ia akan muncul di bawah.
            </p>
          )}
        </div>

        <div className="installPromptActions">
          {!showIosHelp && installPrompt && (
            <button type="button" className="installPromptPrimary" onClick={installAndroid}>
              Install app
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
