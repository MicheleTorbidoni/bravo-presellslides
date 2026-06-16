// Prospect-facing criticality hub. Autonomous UI — no template design system,
// no AppShell, raw Tailwind only. Rendered inside the shared 16:9 Stage so it
// matches the slide flow and closing page shown to the prospect.
import { Check } from "lucide-react"
import { Stage } from "./Stage"

export type Criticality = { id: number; label: string }

export function Hub({
  criticalities,
  selected,
  discussed,
  prefiltered,
  onToggle,
  onStart,
}: {
  criticalities: Criticality[]
  selected: Set<number>
  discussed: number[]
  prefiltered: boolean
  onToggle: (id: number) => void
  onStart: () => void
}) {
  const hasPending = criticalities.some(
    (c) => selected.has(c.id) && !discussed.includes(c.id),
  )
  const anyDiscussed = criticalities.some((c) => discussed.includes(c.id))

  return (
    <Stage>
      <div className="flex h-full w-full flex-col items-center justify-center px-8 py-16">
        <div className="w-full max-w-5xl text-center">
          <h1 className="text-4xl font-semibold tracking-tight text-white sm:text-5xl">
            Dove fa più difficoltà la tua azienda?
          </h1>
        {!prefiltered && (
          <p className="mt-4 text-base text-slate-400">
            Scegli liberamente i temi più rilevanti tra quelli disponibili.
          </p>
        )}

        <ul className="mt-12 flex flex-wrap items-center justify-center gap-3">
          {criticalities.map((c) => {
            const isSelected = selected.has(c.id)
            const isDone = discussed.includes(c.id)
            return (
              <li key={c.id}>
                <button
                  type="button"
                  onClick={() => onToggle(c.id)}
                  aria-pressed={isSelected}
                  className={[
                    "inline-flex items-center gap-2 rounded-full border px-5 py-3 text-base font-medium transition-colors",
                    isDone
                      ? "border-emerald-400/60 bg-emerald-400/15 text-emerald-200"
                      : isSelected
                        ? "border-sky-400 bg-sky-500 text-white"
                        : "border-slate-700 bg-slate-900 text-slate-200 hover:border-slate-500 hover:bg-slate-800",
                  ].join(" ")}
                >
                  {isDone && <Check className="h-4 w-4 shrink-0" />}
                  {c.label}
                </button>
              </li>
            )
          })}
        </ul>

        <div className="mt-14">
          <button
            type="button"
            onClick={onStart}
            disabled={!hasPending}
            className="rounded-full bg-white px-10 py-4 text-lg font-semibold text-slate-950 transition-opacity enabled:hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40"
          >
            {anyDiscussed ? "Continua" : "Avvia presentazione"}
          </button>
          <p className="mt-6 text-sm text-slate-500">
            Premi <kbd className="rounded bg-slate-800 px-1.5 py-0.5 font-mono text-slate-300">C</kbd>{" "}
            in qualsiasi momento per chiudere la conversazione.
          </p>
          </div>
        </div>
      </div>
    </Stage>
  )
}
