import { Head, router } from "@inertiajs/react"
import { Info, Pencil } from "lucide-react"
import { AppShell } from "@/components/AppShell"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { cn } from "@/lib/utils"

type SessionDetail = {
  id: number
  company_name: string | null
  contact_name: string | null
  segment: string | null
  operational_profile: string | null
}

type ProfileStep = { question: string; answer: string }
type Criticality = { id: number; label: string }

export default function PresaleSessionResult({
  session,
  segmentLabel,
  profileSteps,
  criticalities,
  suggested = [],
}: {
  session: SessionDetail
  segmentLabel: string | null
  profileSteps: ProfileStep[]
  criticalities: Criticality[]
  suggested?: number[]
}) {
  return (
    <>
      <Head title="Profilo & criticità">
        <meta
          name="description"
          content="Profilo operativo determinato e criticità rilevanti per il prospect."
        />
        <meta property="og:title" content="Profilo & criticità" />
        <meta
          property="og:description"
          content="Profilo operativo determinato e criticità rilevanti per il prospect."
        />
      </Head>
      <AppShell>
        <div className="border-b border-hairline pb-6">
          <h1>Profilo & criticità</h1>
          <p className="mt-1">
            {session.company_name || "(senza nome)"}
            {session.contact_name ? ` · ${session.contact_name}` : ""}
            {segmentLabel ? ` · ${segmentLabel}` : ""}
          </p>
        </div>

        <div className="mt-6 max-w-2xl">
          <h2 className="text-base font-semibold text-ink-display">
            Profilo operativo
          </h2>
          {profileSteps.length > 0 ? (
            <ul className="mt-3 divide-y divide-hairline overflow-hidden rounded-md border border-hairline bg-page">
              {profileSteps.map((step, i) => (
                <li key={i} className="flex justify-between gap-4 px-4 py-3">
                  <span className="text-sm text-ink-muted">{step.question}</span>
                  <span className="text-sm font-medium text-ink-display">
                    {step.answer}
                  </span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="mt-2 text-ink-muted">Profilazione non ancora completata.</p>
          )}
        </div>

        <div className="mt-8 max-w-2xl">
          <h2 className="text-base font-semibold text-ink-display">
            Criticità rilevanti
          </h2>
          {suggested.length > 0 && (
            <p className="mt-2 text-sm text-ink-muted">
              Le criticità contrassegnate sono già state indicate dal prospect in
              fase di prenotazione.
            </p>
          )}
          {criticalities.length > 0 ? (
            <ul className="mt-3 flex flex-col gap-2">
              {criticalities.map((c) => {
                const isSuggested = suggested.includes(c.id)
                return (
                  <li
                    key={c.id}
                    className={cn(
                      "flex items-center justify-between gap-3 rounded-md border px-4 py-3 text-sm",
                      isSuggested
                        ? "border-accent/40 bg-accent/5 text-ink-display"
                        : "border-hairline bg-page text-ink-body",
                    )}
                  >
                    <span>{c.label}</span>
                    {isSuggested && (
                      <Badge tone="accent" className="shrink-0">
                        Indicata dal prospect
                      </Badge>
                    )}
                  </li>
                )
              })}
            </ul>
          ) : (
            <div className="mt-3 flex items-start gap-3 rounded-md border border-dashed border-hairline px-4 py-4">
              <Info className="mt-0.5 h-4 w-4 shrink-0 text-ink-muted" />
              <p className="text-sm text-ink-muted">
                Nessun mapping per questa combinazione di segmento e profilo. Le
                criticità si potranno scegliere liberamente nella schermata
                successiva.
              </p>
            </div>
          )}
        </div>

        <div className="mt-8 flex items-center justify-between border-t border-hairline pt-6">
          <Button
            variant="ghost"
            onClick={() => router.visit(`/presale_sessions/${session.id}/setup`)}
          >
            <Pencil className="h-4 w-4" />
            Modifica
          </Button>
          <div className="flex items-center gap-3">
            <Button
              variant="secondary"
              onClick={() => router.visit("/presale_sessions")}
            >
              Torna alle sessioni
            </Button>
            <Button
              onClick={() =>
                router.visit(`/presale_sessions/${session.id}/present`)
              }
            >
              Avvia presentazione
            </Button>
          </div>
        </div>
      </AppShell>
    </>
  )
}
