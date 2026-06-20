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
  // null when captured from the hub (no criticality/slide in context).
  criticality_id: number | null
  text: string
  slide_id: string | null
  asked_at: string
}

type View =
  | { name: "intro" }
  | { name: "hub" }
  | { name: "flow"; criticalityId: number }
  | { name: "closing" }

// Step/phase navigation math, shared by the intro and the per-criticality flow.
// advancePosition returns the next position, or null when past the last phase of
// the last step (the caller decides what "end" means: enter the hub / complete the
// flow). backPosition returns the previous position, or null at the very start.
function advancePosition(
  steps: Step[],
  pos: { stepIndex: number; phaseIndex: number },
) {
  const phases = steps[pos.stepIndex]?.phases ?? []
  if (pos.phaseIndex < phases.length - 1) {
    return { stepIndex: pos.stepIndex, phaseIndex: pos.phaseIndex + 1 }
  }
  if (pos.stepIndex < steps.length - 1) {
    return { stepIndex: pos.stepIndex + 1, phaseIndex: 0 }
  }
  return null
}

function backPosition(
  steps: Step[],
  pos: { stepIndex: number; phaseIndex: number },
) {
  if (pos.phaseIndex > 0) {
    return { stepIndex: pos.stepIndex, phaseIndex: pos.phaseIndex - 1 }
  }
  if (pos.stepIndex > 0) {
    const prevPhases = steps[pos.stepIndex - 1]?.phases ?? []
    return {
      stepIndex: pos.stepIndex - 1,
      phaseIndex: Math.max(0, prevPhases.length - 1),
    }
  }
  return null
}

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
  introSteps,
  discussedCriticalities,
  stepsByCriticality,
  capturedQuestions,
}: {
  session: SessionDetail
  criticalities: Criticality[]
  prefiltered: boolean
  introSteps: Step[]
  discussedCriticalities: number[]
  stepsByCriticality: Record<number, Step[]>
  capturedQuestions: CapturedQuestion[]
}) {
  // The intro plays first when present; otherwise land straight on the hub.
  const [view, setView] = useState<View>(
    introSteps.length > 0 ? { name: "intro" } : { name: "hub" },
  )
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

  // Finishing the intro enters the hub (resetting the ephemeral position). From
  // here on the session behaves exactly as before — the intro never replays.
  const enterHub = useCallback(() => {
    setPosition({ stepIndex: 0, phaseIndex: 0 })
    setView({ name: "hub" })
  }, [])

  // Advance: step through a step's phases, then to the next step, then end the
  // sequence. The intro and the flow share the step/phase math (advancePosition);
  // only the "end" differs — the intro enters the hub, a flow completes (marking
  // the criticality discussed). Empty criticalities complete immediately.
  const advance = useCallback(() => {
    const steps =
      view.name === "intro"
        ? introSteps
        : view.name === "flow"
          ? (stepsByCriticality[view.criticalityId] ?? [])
          : null
    if (!steps) return

    if (view.name === "flow" && steps.length === 0) {
      completeFlow(view.criticalityId)
      return
    }
    const next = advancePosition(steps, position)
    if (next) {
      setPosition(next)
    } else if (view.name === "intro") {
      enterHub()
    } else if (view.name === "flow") {
      completeFlow(view.criticalityId)
    }
  }, [view, position, introSteps, stepsByCriticality, completeFlow, enterHub])

  // Back: mirror of advance. Stays put at the very first phase of the first step.
  const back = useCallback(() => {
    const steps =
      view.name === "intro"
        ? introSteps
        : view.name === "flow"
          ? (stepsByCriticality[view.criticalityId] ?? [])
          : null
    if (!steps) return

    const prev = backPosition(steps, position)
    if (prev) setPosition(prev)
  }, [view, position, introSteps, stepsByCriticality])

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
      } else if (
        (e.key === "q" || e.key === "Q") &&
        (view.name === "flow" || view.name === "hub")
      ) {
        // Capture a question from a flow (bound to the slide) or the hub (unbound).
        e.preventDefault()
        setQuestionOpen(true)
      } else if (view.name === "flow" || view.name === "intro") {
        if (e.key === "ArrowRight") {
          e.preventDefault()
          advance()
        } else if (e.key === "ArrowLeft") {
          e.preventDefault()
          back()
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

  // Persist a captured question (auto-save). In a flow it's bound to the current
  // step/criticality; from the hub there's no such context, so both are null.
  function saveQuestion(text: string) {
    if (view.name !== "flow" && view.name !== "hub") return
    const entry: CapturedQuestion = {
      id: crypto.randomUUID(),
      text,
      criticality_id: view.name === "flow" ? view.criticalityId : null,
      slide_id: view.name === "flow" ? (currentStep?.id ?? null) : null,
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

      {view.name === "intro" && (
        <SlidePlayer
          step={introSteps[position.stepIndex] ?? null}
          phaseIndex={position.phaseIndex}
          companyName={session.company_name}
          contactName={session.contact_name}
          onAdvanceClick={advance}
        />
      )}

      {view.name === "hub" && (
        <Hub
          criticalities={criticalities}
          discussed={discussed}
          prefiltered={prefiltered}
          onPick={pick}
        />
      )}

      {view.name === "flow" && (
        <SlidePlayer
          step={currentStep}
          phaseIndex={position.phaseIndex}
          companyName={session.company_name}
          contactName={session.contact_name}
          onAdvanceClick={advance}
        />
      )}

      {/* Question capture — opened with Q from a flow or the hub (keyboard handler
          gates which views allow it); rendered here so it overlays either one. */}
      {questionOpen && (
        <QuestionCapture
          onSave={saveQuestion}
          onCancel={() => setQuestionOpen(false)}
        />
      )}

      {view.name === "closing" && (
        <Closing
          companyName={session.company_name}
          contactName={session.contact_name}
          onBack={() => setView({ name: "hub" })}
          onDebrief={() =>
            router.visit(`/presale_sessions/${session.id}/debrief`)
          }
        />
      )}
    </>
  )
}
