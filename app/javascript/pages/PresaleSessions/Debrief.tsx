import { FormEvent, useEffect, useRef, useState } from "react"
import { Head, router, useForm, usePage } from "@inertiajs/react"
import { Check, Copy, Plus, Send, Trash2 } from "lucide-react"
import { AppShell } from "@/components/AppShell"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog"
import { apiPatch } from "@/lib/api"
import type { PageProps } from "@/types/inertia"

type SessionStatus = "in_progress" | "closed" | "recap_sent"

type SessionDetail = {
  id: number
  company_name: string | null
  contact_name: string | null
  segment: string | null
  operational_profile: string | null
  status: SessionStatus
}

type ProfileStep = { question: string; answer: string }

type Question = {
  id: string
  text: string
  criticality_id: number | null
  slide_id: string | null
  asked_at: string
  criticality_label: string
}

function statusBadge(status: SessionStatus): {
  label: string
  tone: "accent" | "neutral" | "signal"
} {
  switch (status) {
    case "recap_sent":
      return { label: "Recap inviato", tone: "signal" }
    case "closed":
      return { label: "Chiusa", tone: "neutral" }
    default:
      return { label: "In corso", tone: "accent" }
  }
}

export default function PresaleSessionDebrief({
  session,
  segmentLabel,
  profileSteps,
  discussedCriticalities,
  capturedQuestions,
  defaultRecapBody,
  publicRecapUrl,
}: {
  session: SessionDetail
  segmentLabel: string | null
  profileSteps: ProfileStep[]
  discussedCriticalities: string[]
  capturedQuestions: Question[]
  defaultRecapBody: string
  publicRecapUrl: string | null
}) {
  const { props } = usePage<PageProps>()
  const errors = props.errors ?? {}

  // Questions are edited locally and auto-saved (debounced) via the same raw-fetch
  // endpoint used elsewhere — the whole array is PATCHed, mirroring Present.tsx.
  const [questions, setQuestions] = useState<Question[]>(capturedQuestions)
  const firstRender = useRef(true)
  useEffect(() => {
    if (firstRender.current) {
      firstRender.current = false
      return
    }
    const timer = setTimeout(() => {
      void apiPatch(`/presale_sessions/${session.id}`, {
        captured_questions: questions.map((q) => ({
          id: q.id,
          text: q.text,
          criticality_id: q.criticality_id,
          slide_id: q.slide_id,
          asked_at: q.asked_at,
        })),
      })
    }, 400)
    return () => clearTimeout(timer)
  }, [questions, session.id])

  function editQuestion(id: string, text: string) {
    setQuestions((qs) => qs.map((q) => (q.id === id ? { ...q, text } : q)))
  }
  function removeQuestion(id: string) {
    setQuestions((qs) => qs.filter((q) => q.id !== id))
  }
  function addQuestion() {
    setQuestions((qs) => [
      ...qs,
      {
        id: crypto.randomUUID(),
        text: "",
        criticality_id: null,
        slide_id: null,
        asked_at: new Date().toISOString(),
        criticality_label: "Generale",
      },
    ])
  }

  // Send-recap modal: data bound via useForm, validation errors surfaced from the
  // shared errors prop (the controller redirects with inertia: { errors }).
  const [modalOpen, setModalOpen] = useState(false)
  const form = useForm({ recipient: "", body: defaultRecapBody })

  // Copy-to-clipboard for the prospect's public recap link (same pattern as the
  // design-system CodeBlock). The link exists only once the recap has been sent.
  const [copied, setCopied] = useState(false)
  function copyLink() {
    if (!publicRecapUrl) return
    void navigator.clipboard.writeText(publicRecapUrl)
    setCopied(true)
    setTimeout(() => setCopied(false), 1500)
  }

  function sendRecap(e: FormEvent) {
    e.preventDefault()
    form.post(`/presale_sessions/${session.id}/recap`, {
      preserveScroll: true,
      onSuccess: () => setModalOpen(false),
    })
  }

  const badge = statusBadge(session.status)

  return (
    <>
      <Head title="Debrief">
        <meta
          name="description"
          content="Riepilogo della call, domande catturate e invio del recap via email al prospect."
        />
        <meta property="og:title" content="Debrief" />
        <meta
          property="og:description"
          content="Riepilogo della call, domande catturate e invio del recap via email al prospect."
        />
      </Head>
      <AppShell>
        <div className="flex items-start justify-between gap-4 border-b border-hairline pb-6">
          <div>
            <h1>Debrief</h1>
            <p className="mt-1">
              {session.company_name || "(senza nome)"}
              {session.contact_name ? ` · ${session.contact_name}` : ""}
              {segmentLabel ? ` · ${segmentLabel}` : ""}
            </p>
          </div>
          <Badge tone={badge.tone}>{badge.label}</Badge>
        </div>

        {props.flash?.notice && (
          <p className="mt-6 text-sm text-accent">{props.flash.notice}</p>
        )}

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
            <p className="mt-2 text-ink-muted">Profilazione non completata.</p>
          )}
        </div>

        <div className="mt-8 max-w-2xl">
          <h2 className="text-base font-semibold text-ink-display">
            Criticità discusse
          </h2>
          {discussedCriticalities.length > 0 ? (
            <ul className="mt-3 flex flex-wrap gap-2">
              {discussedCriticalities.map((label, i) => (
                <li key={i}>
                  <Badge tone="accent">{label}</Badge>
                </li>
              ))}
            </ul>
          ) : (
            <p className="mt-2 text-ink-muted">
              Nessuna criticità marcata come discussa.
            </p>
          )}
        </div>

        <div className="mt-8 max-w-2xl">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-semibold text-ink-display">
              Domande catturate
            </h2>
            <Button variant="secondary" size="sm" onClick={addQuestion}>
              <Plus className="h-4 w-4" />
              Aggiungi domanda
            </Button>
          </div>
          {questions.length > 0 ? (
            <ul className="mt-3 flex flex-col gap-2">
              {questions.map((q) => (
                <li key={q.id} className="flex items-center gap-2">
                  <span className="w-28 shrink-0 text-xs text-ink-muted">
                    {q.criticality_label}
                  </span>
                  <Input
                    value={q.text}
                    placeholder="Testo della domanda"
                    onChange={(e) => editQuestion(q.id, e.target.value)}
                  />
                  <Button
                    variant="ghost"
                    size="icon"
                    aria-label="Rimuovi domanda"
                    onClick={() => removeQuestion(q.id)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </li>
              ))}
            </ul>
          ) : (
            <p className="mt-2 text-ink-muted">
              Nessuna domanda catturata durante la call.
            </p>
          )}
        </div>

        <div className="mt-8 max-w-2xl">
          <h2 className="text-base font-semibold text-ink-display">
            Link per il prospect
          </h2>
          {publicRecapUrl ? (
            <div className="mt-3 flex items-center gap-2">
              <Input value={publicRecapUrl} readOnly aria-label="Link pubblico" />
              <Button
                variant="secondary"
                size="icon"
                aria-label="Copia link"
                onClick={copyLink}
              >
                {copied ? (
                  <Check className="h-4 w-4 text-accent" />
                ) : (
                  <Copy className="h-4 w-4" />
                )}
              </Button>
            </div>
          ) : (
            <p className="mt-2 text-ink-muted">
              Il link sarà disponibile dopo l'invio del recap.
            </p>
          )}
        </div>

        <div className="mt-8 flex items-center justify-between border-t border-hairline pt-6">
          <Button
            variant="secondary"
            onClick={() => router.visit("/presale_sessions")}
          >
            Torna alle sessioni
          </Button>
          <Button onClick={() => setModalOpen(true)}>
            <Send className="h-4 w-4" />
            Invia recap via email
          </Button>
        </div>

        <Dialog open={modalOpen} onOpenChange={setModalOpen}>
          <DialogContent size="lg">
            <DialogHeader>
              <DialogTitle>Invia recap via email</DialogTitle>
              <DialogDescription>
                Rivedi destinatario e testo prima dell'invio.
              </DialogDescription>
            </DialogHeader>

            <form onSubmit={sendRecap} className="space-y-4">
              <div className="space-y-2">
                <label htmlFor="recipient">Destinatario</label>
                <Input
                  id="recipient"
                  type="email"
                  placeholder="email@azienda.it"
                  autoFocus
                  aria-invalid={!!errors.recipient}
                  value={form.data.recipient}
                  onChange={(e) => form.setData("recipient", e.target.value)}
                />
                {errors.recipient && (
                  <p className="text-xs text-danger-display">{errors.recipient}</p>
                )}
              </div>

              <div className="space-y-2">
                <label htmlFor="body">Corpo del recap</label>
                <textarea
                  id="body"
                  className="form-control form-control-textarea min-h-[18rem]"
                  aria-invalid={!!errors.body}
                  value={form.data.body}
                  onChange={(e) => form.setData("body", e.target.value)}
                />
                {errors.body && (
                  <p className="text-xs text-danger-display">{errors.body}</p>
                )}
              </div>

              <DialogFooter>
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => setModalOpen(false)}
                >
                  Annulla
                </Button>
                <Button type="submit" disabled={form.processing}>
                  <Send className="h-4 w-4" />
                  Invia recap
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </AppShell>
    </>
  )
}
