import { Head, Link, router } from "@inertiajs/react"
import { ChevronRight, ClipboardList, Plus } from "lucide-react"
import { AppShell } from "@/components/AppShell"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"

type SessionStatus = "in_progress" | "closed" | "recap_sent"

type SessionRow = {
  id: number
  company_name: string | null
  status: SessionStatus
  profiled: boolean
  created_at: string
}

type BadgeTone = "accent" | "neutral" | "signal" | "muted"

// In-progress sessions are split into two levels: "Da compilare" before the
// profiling has been completed, "In corso" once a profile has been determined.
function statusBadge(session: SessionRow): { label: string; tone: BadgeTone } {
  switch (session.status) {
    case "closed":
      return { label: "Chiusa", tone: "neutral" }
    case "recap_sent":
      return { label: "Recap inviato", tone: "signal" }
    default:
      return session.profiled
        ? { label: "In corso", tone: "accent" }
        : { label: "Da compilare", tone: "muted" }
  }
}

export default function PresaleSessionsIndex({
  sessions,
}: {
  sessions: SessionRow[]
}) {
  function createSession() {
    router.post("/presale_sessions")
  }

  return (
    <>
      <Head title="Sessioni">
        <meta
          name="description"
          content="Le tue sessioni di pre-sale: crea una nuova sessione e riprendi quelle esistenti."
        />
        <meta property="og:title" content="Sessioni" />
        <meta
          property="og:description"
          content="Le tue sessioni di pre-sale: crea una nuova sessione e riprendi quelle esistenti."
        />
      </Head>
      <AppShell>
        <div className="border-b border-hairline pb-6">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <h1>Sessioni</h1>
              <p className="mt-1">
                {sessions.length}{" "}
                {sessions.length === 1 ? "sessione" : "sessioni"} di pre-sale.
              </p>
            </div>
            <Button onClick={createSession}>
              <Plus className="h-4 w-4" />
              Nuova sessione
            </Button>
          </div>
        </div>

        {sessions.length === 0 ? (
          <div className="mt-6 flex flex-col items-center gap-3 rounded-md border border-dashed border-hairline px-6 py-12 text-center">
            <ClipboardList className="h-6 w-6 text-ink-muted" />
            <p className="text-ink-muted">
              Nessuna sessione ancora. Crea la prima per iniziare.
            </p>
          </div>
        ) : (
          <ul className="mt-6 divide-y divide-hairline overflow-hidden rounded-md border border-hairline bg-page">
            {sessions.map((session) => {
              const badge = statusBadge(session)
              return (
                <li key={session.id}>
                  <Link
                    href={`/presale_sessions/${session.id}/${session.profiled ? "result" : "setup"}`}
                    className="flex items-center gap-3 px-4 py-3 no-underline hover:bg-surface"
                  >
                    <ClipboardList className="h-4 w-4 text-ink-muted" />
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-medium text-ink-display">
                        {session.company_name || "(senza nome)"}
                      </div>
                      <div className="truncate text-xs text-ink-muted">
                        Creata {formatDate(session.created_at)}
                      </div>
                    </div>
                    <Badge tone={badge.tone}>{badge.label}</Badge>
                    <ChevronRight className="h-4 w-4 text-ink-muted" />
                  </Link>
                </li>
              )
            })}
          </ul>
        )}
      </AppShell>
    </>
  )
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  })
}
