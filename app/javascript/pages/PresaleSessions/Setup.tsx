import { useEffect, useRef, useState } from "react"
import { Head, router } from "@inertiajs/react"
import { ArrowRight, Check, X } from "lucide-react"
import { AppShell } from "@/components/AppShell"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { apiPatch } from "@/lib/api"
import { cn } from "@/lib/utils"

type Segment = { id: string; label: string }

type SessionDetail = {
  id: number
  company_name: string | null
  contact_name: string | null
  segment: string | null
}

export default function PresaleSessionSetup({
  session,
  segments,
}: {
  session: SessionDetail
  segments: Segment[]
}) {
  const [companyName, setCompanyName] = useState(session.company_name ?? "")
  const [contactName, setContactName] = useState(session.contact_name ?? "")
  const [segment, setSegment] = useState<string | null>(session.segment)
  const [showError, setShowError] = useState(false)

  const url = `/presale_sessions/${session.id}`

  // Debounced auto-save: persist the prospect data as the operator fills it in,
  // so nothing is lost if the browser is closed mid-setup.
  const firstRender = useRef(true)
  useEffect(() => {
    if (firstRender.current) {
      firstRender.current = false
      return
    }
    const timer = setTimeout(() => {
      void apiPatch(url, {
        company_name: companyName,
        contact_name: contactName,
        segment,
      })
    }, 400)
    return () => clearTimeout(timer)
  }, [companyName, contactName, segment, url])

  async function continueToProfiling() {
    if (!segment) {
      setShowError(true)
      return
    }
    await apiPatch(url, {
      company_name: companyName,
      contact_name: contactName,
      segment,
    })
    router.visit(`/presale_sessions/${session.id}/profiling`)
  }

  return (
    <>
      <Head title="Nuova sessione — Setup">
        <meta
          name="description"
          content="Inserisci i dati del prospect e scegli il segmento industriale per avviare la profilazione."
        />
        <meta property="og:title" content="Nuova sessione — Setup" />
        <meta
          property="og:description"
          content="Inserisci i dati del prospect e scegli il segmento industriale per avviare la profilazione."
        />
      </Head>
      <AppShell>
        <div className="border-b border-hairline pb-6">
          <h1>Setup sessione</h1>
          <p className="mt-1">
            Dati del prospect e segmento industriale. Queste schermate non vengono
            mostrate al prospect.
          </p>
        </div>

        <div className="mt-6 max-w-xl space-y-5">
          <div className="space-y-2">
            <label htmlFor="company_name">Nome azienda prospect</label>
            <Input
              id="company_name"
              value={companyName}
              onChange={(e) => setCompanyName(e.target.value)}
              autoFocus
            />
          </div>
          <div className="space-y-2">
            <label htmlFor="contact_name">Nome contatto prospect</label>
            <Input
              id="contact_name"
              value={contactName}
              onChange={(e) => setContactName(e.target.value)}
            />
          </div>
        </div>

        <div className="mt-8">
          <h2 className="text-base font-semibold text-ink-display">
            Segmento industriale
          </h2>
          <div className="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-3">
            {segments.map((seg) => {
              const selected = segment === seg.id
              return (
                <button
                  key={seg.id}
                  type="button"
                  onClick={() => {
                    setSegment(seg.id)
                    setShowError(false)
                  }}
                  aria-pressed={selected}
                  className={cn(
                    "flex items-center justify-between gap-2 rounded-md border px-4 py-3 text-left text-sm transition-colors",
                    selected
                      ? "border-accent bg-accent-faded text-accent-display"
                      : "border-hairline text-ink-body hover:bg-surface",
                  )}
                >
                  <span>{seg.label}</span>
                  {selected && <Check className="h-4 w-4 shrink-0" />}
                </button>
              )
            })}
          </div>
          {showError && (
            <p className="mt-2 text-xs text-danger-display">
              Seleziona un segmento per continuare.
            </p>
          )}
        </div>

        <div className="mt-8 flex items-center justify-between border-t border-hairline pt-6">
          <Button
            variant="ghost"
            onClick={() => router.visit("/presale_sessions")}
          >
            <X className="h-4 w-4" />
            Chiudi
          </Button>
          <Button onClick={continueToProfiling}>
            Avanti
            <ArrowRight className="h-4 w-4" />
          </Button>
        </div>
      </AppShell>
    </>
  )
}
