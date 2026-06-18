// Prospect-facing presentation surface. Single autonomous Inertia page — NO
// template design system, NO AppShell — that switches between the hub, a
// per-criticality slide flow (the player) and the closing page entirely in
// client-side state, since presentation state is ephemeral (PRD data model §2).
import { useCallback, useEffect, useState } from "react"
import { Head, router } from "@inertiajs/react"
import { apiPatch } from "@/lib/api"
import { Hub, type Criticality } from "@/components/present/Hub"
import { SlidePlayer, type Step } from "@/components/present/SlidePlayer"
import { QuestionCapture } from "@/components/present/QuestionCapture"
import { Closing } from "@/components/present/Closing"

type SessionDetail = {
  id: number
  company_name: string | null
  contact_name: string | null
  segment: string | null
}

type CapturedQuestion = {
  id: string
  text: string
  criticality_id: number
  slide_id: string | null
  asked_at: string
}

type View =
  | { name: "hub" }
  | { name: "flow"; criticalityId: number }
  | { name: "closing" }

// Toggles native fullscreen on the whole document. Reads `document` only at call
// time (inside the handler), so the module stays SSR-safe.
function toggleFullscreen() {
  if (typeof document === "undefined") return
  if (document.fullscreenElement) {
    void document.exitFullscreen?.()
  } else {
    void document.documentElement.requestFullscreen?.()
  }
}

export default function Present({
  session,
  criticalities,
  prefiltered,
  discussedCriticalities,
  stepsByCriticality,
  capturedQuestions,
}: {
  session: SessionDetail
  criticalities: Criticality[]
  prefiltered: boolean
  discussedCriticalities: number[]
  stepsByCriticality: Record<number, Step[]>
  capturedQuestions: CapturedQuestion[]
}) {
  const [view, setView] = useState<View>({ name: "hub" })
  const [discussed, setDiscussed] = useState<number[]>(discussedCriticalities)
  // Ephemeral position within the current flow: which step, and which phase of a
  // multi-phase step. Reset every time a flow is entered.
  const [position, setPosition] = useState({ stepIndex: 0, phaseIndex: 0 })
  const [questionOpen, setQuestionOpen] = useState(false)
  const [captured, setCaptured] = useState<CapturedQuestion[]>(capturedQuestions)

  const flowSteps =
    view.name === "flow" ? (stepsByCriticality[view.criticalityId] ?? []) : []
  const currentStep: Step | null = flowSteps[position.stepIndex] ?? null

  // Reaching the closing page concludes the conversation, so the session is
  // marked closed (persisted). Returning to the hub afterwards is allowed.
  const goClosing = useCallback(() => {
    setView({ name: "closing" })
    void apiPatch(`/presale_sessions/${session.id}`, { status: "closed" })
  }, [session.id])

  // Completing a flow consolidates the criticality as discussed (persisted) and
  // returns to the hub, where it now renders as completed.
  const completeFlow = useCallback(
    (id: number) => {
      const next = discussed.includes(id) ? discussed : [...discussed, id]
      setDiscussed(next)
      setView({ name: "hub" })
      void apiPatch(`/presale_sessions/${session.id}`, {
        discussed_criticalities: next,
      })
    },
    [discussed, session.id],
  )

  // Advance: step through a step's phases, then to the next step, then complete
  // the flow when past the last step. Empty criticalities complete immediately.
  const advance = useCallback(() => {
    if (view.name !== "flow") return
    const steps = stepsByCriticality[view.criticalityId] ?? []
    if (steps.length === 0) {
      completeFlow(view.criticalityId)
      return
    }
    const phases = steps[position.stepIndex]?.phases ?? []
    if (position.phaseIndex < phases.length - 1) {
      setPosition({
        stepIndex: position.stepIndex,
        phaseIndex: position.phaseIndex + 1,
      })
    } else if (position.stepIndex < steps.length - 1) {
      setPosition({ stepIndex: position.stepIndex + 1, phaseIndex: 0 })
    } else {
      completeFlow(view.criticalityId)
    }
  }, [view, position, stepsByCriticality, completeFlow])

  // Back: mirror of advance. Stays put at the very first phase of the first step.
  const back = useCallback(() => {
    if (view.name !== "flow") return
    const steps = stepsByCriticality[view.criticalityId] ?? []
    if (position.phaseIndex > 0) {
      setPosition({
        stepIndex: position.stepIndex,
        phaseIndex: position.phaseIndex - 1,
      })
    } else if (position.stepIndex > 0) {
      const prevPhases = steps[position.stepIndex - 1]?.phases ?? []
      setPosition({
        stepIndex: position.stepIndex - 1,
        phaseIndex: Math.max(0, prevPhases.length - 1),
      })
    }
  }, [view, position, stepsByCriticality])

  // Operator keyboard shortcuts. Global shortcuts (work from any view): C → closing,
  // S → leave to the sessions list, F/F11 → fullscreen. Flow-only: → advance,
  // ← back, Q → capture a question. The question overlay swallows its own keys.
  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      const target = e.target as HTMLElement | null
      const typing =
        target?.tagName === "INPUT" ||
        target?.tagName === "TEXTAREA" ||
        target?.isContentEditable
      if (typing || questionOpen) return

      if (e.key === "c" || e.key === "C") {
        e.preventDefault()
        goClosing()
      } else if (e.key === "s" || e.key === "S") {
        e.preventDefault()
        router.visit("/presale_sessions")
      } else if (e.key === "f" || e.key === "F" || e.key === "F11") {
        e.preventDefault()
        toggleFullscreen()
      } else if (view.name === "flow") {
        if (e.key === "ArrowRight") {
          e.preventDefault()
          advance()
        } else if (e.key === "ArrowLeft") {
          e.preventDefault()
          back()
        } else if (e.key === "q" || e.key === "Q") {
          e.preventDefault()
          setQuestionOpen(true)
        }
      }
    }
    window.addEventListener("keydown", onKeyDown)
    return () => window.removeEventListener("keydown", onKeyDown)
  }, [goClosing, advance, back, view, questionOpen])

  // Clicking a criticality pill starts its flow immediately (no separate "start"
  // button) — with 4-5 relevant criticalities per set they all fit on the hub.
  // Already-discussed criticalities can be re-entered. Resets the flow position.
  function pick(id: number) {
    setPosition({ stepIndex: 0, phaseIndex: 0 })
    setView({ name: "flow", criticalityId: id })
  }

  // Persist a captured question (auto-save), bound to the current step/criticality.
  function saveQuestion(text: string) {
    if (view.name !== "flow") return
    const entry: CapturedQuestion = {
      id: crypto.randomUUID(),
      text,
      criticality_id: view.criticalityId,
      slide_id: currentStep?.id ?? null,
      asked_at: new Date().toISOString(),
    }
    const next = [...captured, entry]
    setCaptured(next)
    setQuestionOpen(false)
    void apiPatch(`/presale_sessions/${session.id}`, {
      captured_questions: next,
    })
  }

  return (
    <>
      <Head title="Presentazione">
        <meta
          name="description"
          content="Hub delle criticità e presentazione su misura per il prospect."
        />
        <meta property="og:title" content="Presentazione" />
        <meta
          property="og:description"
          content="Hub delle criticità e presentazione su misura per il prospect."
        />
      </Head>

      {view.name === "hub" && (
        <Hub
          criticalities={criticalities}
          discussed={discussed}
          prefiltered={prefiltered}
          onPick={pick}
        />
      )}

      {view.name === "flow" && (
        <>
          <SlidePlayer
            step={currentStep}
            phaseIndex={position.phaseIndex}
            companyName={session.company_name}
            contactName={session.contact_name}
            onAdvanceClick={advance}
          />
          {questionOpen && (
            <QuestionCapture
              onSave={saveQuestion}
              onCancel={() => setQuestionOpen(false)}
            />
          )}
        </>
      )}

      {view.name === "closing" && (
        <Closing
          companyName={session.company_name}
          contactName={session.contact_name}
          onBack={() => setView({ name: "hub" })}
        />
      )}
    </>
  )
}
