// Prospect-facing 16:9 slide player (Milestone 4). Autonomous UI — no template
// design system, raw Tailwind only. Purely presentational: navigation state and
// keyboard handling live in Present.tsx (which also binds captured questions to
// the current slide); this component just renders the current slide/step.
//
// Styling here is deliberately functional/placeholder — the Figma chrome + the
// "chrome + transparent PNG" convention arrive in Milestone 5.
import { useState } from "react"
import { Stage } from "./Stage"

export type SlideStep = {
  asset: string
  assetIsSegmentVariant: boolean
}

export type Slide = {
  id: string
  type: "concept" | "screenshot" | "sequence"
  title: string
  body: string | null
  asset?: string
  assetIsSegmentVariant?: boolean
  steps?: SlideStep[]
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

// Builds the runtime asset URL served by PresentationAssetsController. Segment
// variants come from the prospect's segment folder; everything else from common.
function assetUrl(
  asset: string,
  isSegmentVariant: boolean | undefined,
  segment: string | null,
): string {
  const folder = isSegmentVariant && segment ? segment : "common"
  return `/presentation_assets/${folder}/${asset}`
}

// A bitmap that degrades to a labelled grey placeholder when the PNG is missing
// (most criticalities have no real assets yet).
function SlideImage({ src, name }: { src: string; name: string }) {
  const [failed, setFailed] = useState(false)
  if (failed) {
    return (
      <div className="flex h-full w-full items-center justify-center rounded-lg border border-dashed border-slate-700 bg-slate-800/50">
        <span className="px-4 text-center font-mono text-sm text-slate-500">
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
      className="max-h-full max-w-full object-contain"
    />
  )
}

export function SlidePlayer({
  slide,
  stepIndex,
  segment,
  companyName,
  contactName,
  onAdvanceClick,
}: {
  slide: Slide | null
  stepIndex: number
  segment: string | null
  companyName: string | null
  contactName: string | null
  onAdvanceClick: () => void
}) {
  return (
    <Stage onClick={onAdvanceClick}>
      {/* Bravo Manufacturing logo — placeholder placement, refined in M5. */}
      <div className="absolute right-6 top-5 z-10 text-sm font-semibold tracking-wide text-slate-400">
        Bravo Manufacturing
      </div>

      {slide ? (
        <SlideBody
          slide={slide}
          stepIndex={stepIndex}
          segment={segment}
          companyName={companyName}
          contactName={contactName}
        />
      ) : (
        <div className="flex h-full w-full flex-col items-center justify-center px-12 text-center">
          <h1 className="text-3xl font-semibold text-white">
            Contenuto non ancora disponibile
          </h1>
          <p className="mt-4 text-slate-400">
            Questa criticità non ha ancora slide. Premi → per concludere il
            flusso.
          </p>
        </div>
      )}
    </Stage>
  )
}

function SlideBody({
  slide,
  stepIndex,
  segment,
  companyName,
  contactName,
}: {
  slide: Slide
  stepIndex: number
  segment: string | null
  companyName: string | null
  contactName: string | null
}) {
  const title = interpolate(slide.title, companyName, contactName)
  const body = slide.body
    ? interpolate(slide.body, companyName, contactName)
    : null

  // The active bitmap: a sequence shows its current step; concept/screenshot show
  // their single asset.
  let image: { asset: string; variant: boolean | undefined } | null = null
  if (slide.type === "sequence" && slide.steps?.[stepIndex]) {
    const step = slide.steps[stepIndex]
    image = { asset: step.asset, variant: step.assetIsSegmentVariant }
  } else if (slide.asset) {
    image = { asset: slide.asset, variant: slide.assetIsSegmentVariant }
  }

  return (
    <div className="flex h-full w-full flex-col px-[6%] py-[5%]">
      <h1 className="max-w-[80%] text-4xl font-semibold tracking-tight text-white">
        {title}
      </h1>
      {body && <p className="mt-3 max-w-[70%] text-lg text-slate-300">{body}</p>}

      <div className="mt-6 flex min-h-0 flex-1 items-center justify-center">
        {image && (
          <SlideImage
            src={assetUrl(image.asset, image.variant, segment)}
            name={image.asset}
          />
        )}
      </div>

      {slide.type === "sequence" && slide.steps && slide.steps.length > 1 && (
        <div className="mt-4 flex items-center justify-center gap-2">
          {slide.steps.map((_, i) => (
            <span
              key={i}
              className={[
                "h-2 w-2 rounded-full transition-colors",
                i === stepIndex ? "bg-sky-400" : "bg-slate-700",
              ].join(" ")}
            />
          ))}
        </div>
      )}
    </div>
  )
}
