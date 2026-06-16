// Prospect-facing criticality hub. Autonomous UI — no template design system,
// raw Tailwind only, Bravo tokens (bm-*). Figma veste (node 62-241): light grey
// stage, slate title left-aligned, green parallelogram pills (white text); logo
// bottom-left. Rendered inside the shared 16:9 Stage; sizes use cqw so they scale
// with the stage.
//
// Interaction: clicking a pill starts that criticality's flow immediately (no
// separate "start" button — with 4-5 relevant criticalities per set they all fit).
// Already-discussed criticalities render as completed (white pill, amber text,
// shield — Figma node 62-619) and can be re-opened.
import { ShieldCheck } from "lucide-react"
import { Stage } from "./Stage"
import { Logo } from "./Logo"

export type Criticality = { id: number; label: string }

export function Hub({
  criticalities,
  discussed,
  prefiltered,
  onPick,
}: {
  criticalities: Criticality[]
  discussed: number[]
  prefiltered: boolean
  onPick: (id: number) => void
}) {
  return (
    <Stage className="bg-bm-grey text-bm-slate">
      <div className="flex h-full w-full flex-col px-[5.2cqw] py-[2.6cqw]">
        <h1 className="font-bm text-[4.2cqw] leading-[1.05] font-bold tracking-tight text-bm-slate">
          Dove fa più difficoltà la tua azienda?
        </h1>
        {!prefiltered && (
          <p className="mt-[0.8cqw] text-[1.3cqw] text-bm-slate/70">
            Scegli liberamente i temi più rilevanti tra quelli disponibili.
          </p>
        )}

        <ul className="grid flex-1 grid-cols-2 content-center justify-items-center gap-x-[5cqw] gap-y-[2.2cqw] py-[2cqw]">
          {criticalities.map((c) => {
            const isDone = discussed.includes(c.id)
            return (
              <li key={c.id}>
                <button
                  type="button"
                  onClick={() => onPick(c.id)}
                  className={[
                    "-skew-x-12 inline-flex items-center px-[2cqw] py-[1.1cqw] transition-colors",
                    isDone
                      ? "bg-bm-white text-bm-amber hover:bg-bm-white/90"
                      : "bg-bm-green text-bm-white hover:bg-bm-green-bright",
                  ].join(" ")}
                >
                  <span className="flex skew-x-12 items-center gap-[0.7cqw] text-[1.85cqw] font-bold tracking-tight">
                    {isDone && (
                      <ShieldCheck className="size-[1.85cqw] shrink-0 text-bm-amber" />
                    )}
                    {c.label}
                  </span>
                </button>
              </li>
            )
          })}
        </ul>

        <div className="flex items-end justify-between gap-4">
          <Logo variant="color" className="h-[3.4cqw] w-auto" />
          <p className="text-[0.9cqw] text-bm-slate/50">
            Tocca un tema per presentarlo · premi{" "}
            <kbd className="rounded bg-bm-slate/15 px-1 font-mono">C</kbd> per
            chiudere
          </p>
        </div>
      </div>
    </Stage>
  )
}
