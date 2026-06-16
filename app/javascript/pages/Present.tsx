// Prospect-facing presentation surface (Milestone 3). Single autonomous Inertia
// page — NO template design system, NO AppShell — that switches between the hub,
// a per-criticality flow (placeholder until M4) and the closing page entirely in
// client-side state, since presentation state is ephemeral (PRD data model §2).
import { useCallback, useEffect, useState } from "react"
import { Head, router } from "@inertiajs/react"
import { apiPatch } from "@/lib/api"
import { Hub, type Criticality } from "@/components/present/Hub"
import { FlowPlaceholder } from "@/components/present/FlowPlaceholder"
import { Closing } from "@/components/present/Closing"

type SessionDetail = {
  id: number
  company_name: string | null
  contact_name: string | null
}

type View =
  | { name: "hub" }
  | { name: "flow"; criticalityId: number }
  | { name: "closing" }

export default function Present({
  session,
  criticalities,
  prefiltered,
  discussedCriticalities,
}: {
  session: SessionDetail
  criticalities: Criticality[]
  prefiltered: boolean
  discussedCriticalities: number[]
}) {
  const [view, setView] = useState<View>({ name: "hub" })
  const [selected, setSelected] = useState<Set<number>>(new Set())
  const [discussed, setDiscussed] = useState<number[]>(discussedCriticalities)

  // Reaching the closing page concludes the conversation, so the session is
  // marked closed (persisted). Returning to the hub afterwards is allowed.
  const goClosing = useCallback(() => {
    setView({ name: "closing" })
    void apiPatch(`/presale_sessions/${session.id}`, { status: "closed" })
  }, [session.id])

  // Operator keyboard shortcuts (work from any view):
  //   C → jump to the closing page · S → leave the presentation back to the
  //   sessions list (operator escape hatch, full Inertia navigation).
  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      const target = e.target as HTMLElement | null
      const typing =
        target?.tagName === "INPUT" ||
        target?.tagName === "TEXTAREA" ||
        target?.isContentEditable
      if (typing) return
      if (e.key === "c" || e.key === "C") {
        e.preventDefault()
        goClosing()
      } else if (e.key === "s" || e.key === "S") {
        e.preventDefault()
        router.visit("/presale_sessions")
      }
    }
    window.addEventListener("keydown", onKeyDown)
    return () => window.removeEventListener("keydown", onKeyDown)
  }, [goClosing])

  function toggle(id: number) {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  // Start (or continue) with the first selected criticality not yet discussed.
  function start() {
    const nextId = criticalities.find(
      (c) => selected.has(c.id) && !discussed.includes(c.id),
    )?.id
    if (nextId != null) setView({ name: "flow", criticalityId: nextId })
  }

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
          selected={selected}
          discussed={discussed}
          prefiltered={prefiltered}
          onToggle={toggle}
          onStart={start}
        />
      )}

      {view.name === "flow" && (
        <FlowPlaceholder
          criticality={
            criticalities.find((c) => c.id === view.criticalityId) ?? {
              id: view.criticalityId,
              label: "",
            }
          }
          onComplete={() => completeFlow(view.criticalityId)}
        />
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
