// Placeholder for a single criticality's slide flow. M3 only needs to enter/exit
// the loop — the real 16:9 slide player arrives in M4 and will replace this
// component. Autonomous UI, full-bleed, raw Tailwind.
import { ArrowLeft } from "lucide-react"
import type { Criticality } from "./Hub"

export function FlowPlaceholder({
  criticality,
  onComplete,
}: {
  criticality: Criticality
  onComplete: () => void
}) {
  return (
    <div className="flex min-h-screen w-full flex-col items-center justify-center bg-slate-900 px-8 py-16 text-center text-white">
      <p className="text-sm font-medium uppercase tracking-widest text-slate-500">
        Flusso criticità
      </p>
      <h1 className="mt-4 max-w-4xl text-4xl font-semibold tracking-tight text-white sm:text-5xl">
        {criticality.label}
      </h1>
      <p className="mt-6 max-w-xl text-base text-slate-400">
        Il player di slide arriva nel Milestone 4. Per ora questo segnaposto
        rappresenta la presentazione di questa criticità.
      </p>

      <button
        type="button"
        onClick={onComplete}
        className="mt-12 inline-flex items-center gap-2 rounded-full bg-white px-8 py-4 text-lg font-semibold text-slate-950 transition-opacity hover:opacity-90"
      >
        <ArrowLeft className="pointer-events-none h-5 w-5" />
        Concludi flusso → torna all'hub
      </button>
    </div>
  )
}
