import { useMemo, useState } from "react"
import { Head, Link, router } from "@inertiajs/react"
import { ChevronRight, ClipboardList, Plus, Trash2 } from "lucide-react"
import { AppShell } from "@/components/AppShell"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select } from "@/components/ui/select"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog"
import { cn } from "@/lib/utils"

type SessionStatus = "in_progress" | "closed" | "recap_sent"

type SessionRow = {
  id: number
  company_name: string | null
  contact_name: string | null
  segment_label: string | null
  status: SessionStatus
  profiled: boolean
  created_at: string
}

type BadgeTone = "accent" | "neutral" | "signal" | "muted"
type TabKey = "active" | "archive"
type SortKey = "date_desc" | "date_asc" | "company_asc"

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

// Attive = ancora da finire (in_progress); Archivio = concluse (closed) o con
// recap già inviato (recap_sent).
function isActive(session: SessionRow) {
  return session.status === "in_progress"
}

export default function PresaleSessionsIndex({
  sessions,
}: {
  sessions: SessionRow[]
}) {
  const [tab, setTab] = useState<TabKey>("active")
  const [query, setQuery] = useState("")
  const [sort, setSort] = useState<SortKey>("date_desc")
  const [pendingDelete, setPendingDelete] = useState<SessionRow | null>(null)

  const activeCount = useMemo(
    () => sessions.filter(isActive).length,
    [sessions],
  )
  const archiveCount = sessions.length - activeCount

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase()
    return sessions
      .filter((s) => (tab === "active" ? isActive(s) : !isActive(s)))
      .filter((s) => {
        if (!q) return true
        return (
          (s.company_name ?? "").toLowerCase().includes(q) ||
          (s.contact_name ?? "").toLowerCase().includes(q)
        )
      })
      .sort((a, b) => {
        switch (sort) {
          case "date_asc":
            return a.created_at.localeCompare(b.created_at)
          case "company_asc":
            return (a.company_name ?? "").localeCompare(b.company_name ?? "")
          default:
            return b.created_at.localeCompare(a.created_at)
        }
      })
  }, [sessions, tab, query, sort])

  function createSession() {
    router.post("/presale_sessions")
  }

  function confirmDelete() {
    if (!pendingDelete) return
    router.delete(`/presale_sessions/${pendingDelete.id}`, {
      onFinish: () => setPendingDelete(null),
    })
  }

  return (
    <>
      <Head title="Sessioni">
        <meta
          name="description"
          content="Le tue sessioni di pre-sale: crea una nuova sessione, riprendi quelle in corso e consulta l'archivio."
        />
        <meta property="og:title" content="Sessioni" />
        <meta
          property="og:description"
          content="Le tue sessioni di pre-sale: crea una nuova sessione, riprendi quelle in corso e consulta l'archivio."
        />
      </Head>
      <AppShell>
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h1>Sessioni</h1>
            <p className="mt-1">
              Riprendi le sessioni in corso o consulta l'archivio.
            </p>
          </div>
          <Button onClick={createSession}>
            <Plus className="h-4 w-4" />
            Nuova sessione
          </Button>
        </div>

        <nav className="mt-6 flex items-end gap-6 border-b border-hairline">
          <TabButton
            active={tab === "active"}
            onClick={() => setTab("active")}
            label="Attive"
            count={activeCount}
          />
          <TabButton
            active={tab === "archive"}
            onClick={() => setTab("archive")}
            label="Archivio"
            count={archiveCount}
          />
        </nav>

        <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center">
          <Input
            type="search"
            placeholder="Cerca per azienda o contatto"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="sm:max-w-xs"
          />
          <Select
            aria-label="Ordina"
            value={sort}
            onChange={(e) => setSort(e.target.value as SortKey)}
            className="sm:max-w-[14rem]"
          >
            <option value="date_desc">Data (più recenti)</option>
            <option value="date_asc">Data (meno recenti)</option>
            <option value="company_asc">Azienda (A→Z)</option>
          </Select>
        </div>

        {visible.length === 0 ? (
          <div className="mt-6 flex flex-col items-center gap-3 rounded-md border border-dashed border-hairline px-6 py-12 text-center">
            <ClipboardList className="h-6 w-6 text-ink-muted" />
            <p className="text-ink-muted">
              {query.trim()
                ? "Nessuna sessione corrisponde alla ricerca."
                : tab === "active"
                  ? "Nessuna sessione attiva. Crea la prima per iniziare."
                  : "L'archivio è vuoto. Le sessioni concluse compaiono qui."}
            </p>
          </div>
        ) : (
          <ul className="mt-6 divide-y divide-hairline overflow-hidden rounded-md border border-hairline bg-page">
            {visible.map((session) => {
              const badge = statusBadge(session)
              const secondary = [
                session.contact_name,
                session.segment_label,
                `Creata ${formatDate(session.created_at)}`,
              ]
                .filter(Boolean)
                .join(" · ")
              return (
                <li
                  key={session.id}
                  className="flex items-center gap-3 px-4 py-3 hover:bg-surface"
                >
                  <ClipboardList className="h-4 w-4 shrink-0 text-ink-muted" />
                  <Link
                    href={`/presale_sessions/${session.id}/debrief`}
                    className="flex min-w-0 flex-1 items-center gap-3 no-underline"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-medium text-ink-display">
                        {session.company_name || "(senza nome)"}
                      </div>
                      <div className="truncate text-xs text-ink-muted">
                        {secondary}
                      </div>
                    </div>
                    <Badge tone={badge.tone}>{badge.label}</Badge>
                  </Link>
                  {isActive(session) && (
                    <Button asChild variant="secondary" size="sm">
                      <Link
                        href={`/presale_sessions/${session.id}/${session.profiled ? "result" : "setup"}`}
                      >
                        Riprendi
                      </Link>
                    </Button>
                  )}
                  <Button
                    variant="ghost"
                    size="icon"
                    aria-label="Elimina sessione"
                    onClick={() => setPendingDelete(session)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                  <Link
                    href={`/presale_sessions/${session.id}/debrief`}
                    className="no-underline"
                    aria-hidden="true"
                    tabIndex={-1}
                  >
                    <ChevronRight className="h-4 w-4 text-ink-muted" />
                  </Link>
                </li>
              )
            })}
          </ul>
        )}

        <Dialog
          open={pendingDelete !== null}
          onOpenChange={(open) => !open && setPendingDelete(null)}
        >
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Eliminare la sessione?</DialogTitle>
              <DialogDescription>
                {pendingDelete?.company_name
                  ? `La sessione di ${pendingDelete.company_name} verrà eliminata definitivamente, comprese le domande catturate.`
                  : "La sessione verrà eliminata definitivamente, comprese le domande catturate."}
              </DialogDescription>
            </DialogHeader>
            <DialogFooter>
              <Button
                type="button"
                variant="secondary"
                onClick={() => setPendingDelete(null)}
              >
                Annulla
              </Button>
              <Button type="button" variant="danger" onClick={confirmDelete}>
                <Trash2 className="h-4 w-4" />
                Elimina
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </AppShell>
    </>
  )
}

function TabButton({
  active,
  onClick,
  label,
  count,
}: {
  active: boolean
  onClick: () => void
  label: string
  count: number
}) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      onClick={onClick}
      className={cn(
        "-mb-px border-b-2 px-1 py-3 text-sm",
        active
          ? "border-accent font-medium text-accent-display"
          : "border-transparent text-ink-body hover:text-ink-display",
      )}
    >
      {label}{" "}
      <span className="text-ink-muted">({count})</span>
    </button>
  )
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  })
}
