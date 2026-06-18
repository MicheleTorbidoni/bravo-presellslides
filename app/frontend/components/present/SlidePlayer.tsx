// Prospect-facing 16:9 slide player. Autonomous UI — no template design system,
// raw Tailwind only. Purely presentational: navigation state and keyboard handling
// live in Present.tsx (which binds captured questions to the current step); this
// component just renders the current step and its active phase.
//
// File-driven model: a criticality is an ordered list of steps; each step has a
// title/body (overlay, from config) and 1..N phase bitmaps shown in sequence. The
// phase image URLs are already resolved server-side (token > segment > shared) — see
// ContentConfig.steps_for — so this component just displays `step.phases[phaseIndex]`.
import { useState } from "react"
import { Stage } from "./Stage"
import { Logo } from "./Logo"

export type Step = {
  id: string
  title: string | null
  body: string | null
  phases: string[]
}

// Replaces {{company_name}} / {{contact_name}} with the prospect's data, with a
// gentle fallback when a name is missing.
export function interpolate(
  text: string,
  companyName: string | null,
  contactName: string | null,
): string {
  return text
    .replace(/\{\{\s*company_name\s*\}\}/g, companyName?.trim() || "la tua azienda")
    .replace(/\{\{\s*contact_name\s*\}\}/g, contactName?.trim() || "")
}

// A bitmap that degrades to a labelled grey placeholder when the image is missing
// (or fails to load). The player reuses this instance across steps/phases, so the
// failed state is reset whenever `src` changes (adjusting state during render —
// no placeholder flash), otherwise one missing image would poison later valid ones.
function SlideImage({ src, name }: { src: string | undefined; name: string }) {
  const [failed, setFailed] = useState(false)
  const [prevSrc, setPrevSrc] = useState(src)
  if (src !== prevSrc) {
    setPrevSrc(src)
    setFailed(false)
  }
  if (!src || failed) {
    return (
      <div className="flex h-full w-full items-center justify-center rounded-xl border border-dashed border-bm-white/40 bg-bm-white/10">
        <span className="px-4 text-center font-mono text-[1.1cqw] text-bm-white/70">
          {name}
        </span>
      </div>
    )
  }
  return (
    <img
      src={src}
      alt=""
      onError={() => setFailed(true)}
      className="h-full w-full object-contain"
    />
  )
}

export function SlidePlayer({
  step,
  phaseIndex,
  companyName,
  contactName,
  onAdvanceClick,
}: {
  step: Step | null
  phaseIndex: number
  companyName: string | null
  contactName: string | null
  onAdvanceClick: () => void
}) {
  return (
    <Stage onClick={onAdvanceClick} className="bg-bm-green text-bm-white">
      {step ? (
        <StepBody
          step={step}
          phaseIndex={phaseIndex}
          companyName={companyName}
          contactName={contactName}
        />
      ) : (
        <div className="flex h-full w-full flex-col items-center justify-center px-[5.2cqw] text-center">
          <h1 className="font-bm text-[3.2cqw] font-bold text-bm-white">
            Contenuto non ancora disponibile
          </h1>
          <p className="mt-[1cqw] text-[1.4cqw] text-bm-white/80">
            Questa criticità non ha ancora slide. Premi → per concludere il
            flusso.
          </p>
        </div>
      )}

      {/* Bravo Manufacturing logo — bottom-left per Figma (node 62-663). */}
      <Logo
        variant="white"
        className="absolute bottom-[2.4cqw] left-[5.2cqw] z-10 h-[3.4cqw] w-auto"
      />
    </Stage>
  )
}

function StepBody({
  step,
  phaseIndex,
  companyName,
  contactName,
}: {
  step: Step
  phaseIndex: number
  companyName: string | null
  contactName: string | null
}) {
  const title = step.title ? interpolate(step.title, companyName, contactName) : null
  const body = step.body ? interpolate(step.body, companyName, contactName) : null
  const src = step.phases[phaseIndex]
  const showDots = step.phases.length > 1

  return (
    <div className="flex h-full w-full flex-col px-[5.2cqw] pt-[2.6cqw] pb-[7cqw]">
      {title && (
        <h1 className="max-w-[85%] font-bm text-[4.2cqw] leading-[1.05] font-bold tracking-tight text-bm-white">
          {title}
        </h1>
      )}
      {body && (
        <p className="mt-[1cqw] max-w-[70%] text-[1.7cqw] text-bm-white/90">
          {body}
        </p>
      )}

      <div className="mt-[1.5cqw] flex min-h-0 w-full flex-1 items-center justify-center">
        <SlideImage src={src} name={step.id} />
      </div>

      {showDots && (
        <div className="mt-[1.2cqw] flex items-center justify-center gap-[0.7cqw]">
          {step.phases.map((_, i) => (
            <span
              key={i}
              className={[
                "h-[0.9cqw] w-[0.9cqw] rounded-full",
                i === phaseIndex ? "bg-bm-white" : "bg-bm-white/40",
              ].join(" ")}
            />
          ))}
        </div>
      )}
    </div>
  )
}
