// Prospect-facing 16:9 slide player (Milestone 4). Autonomous UI — no template
// design system, raw Tailwind only. Purely presentational: navigation state and
// keyboard handling live in Present.tsx (which also binds captured questions to
// the current slide); this component just renders the current slide/step.
//
// Styling here is deliberately functional/placeholder — the Figma chrome + the
// "chrome + transparent PNG" convention arrive in Milestone 5.
import { useState } from "react"
import { Stage } from "./Stage"
import { Logo } from "./Logo"

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
  // The player reuses this component instance across slides (no key), so a single
  // missing asset would otherwise "poison" every later valid image: `failed`
  // stays true even once `src` points back at an image that loads fine. Reset it
  // whenever the asset changes (adjusting state during render — no placeholder flash).
  const [prevSrc, setPrevSrc] = useState(src)
  if (src !== prevSrc) {
    setPrevSrc(src)
    setFailed(false)
  }
  if (failed) {
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
    <Stage onClick={onAdvanceClick} className="bg-bm-green text-bm-white">
      {slide ? (
        <SlideBody
          slide={slide}
          stepIndex={stepIndex}
          segment={segment}
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
    <div className="flex h-full w-full flex-col px-[5.2cqw] pt-[2.6cqw] pb-[7cqw]">
      <h1 className="max-w-[85%] font-bm text-[4.2cqw] leading-[1.05] font-bold tracking-tight text-bm-white">
        {title}
      </h1>
      {body && (
        <p className="mt-[1cqw] max-w-[70%] text-[1.7cqw] text-bm-white/90">
          {body}
        </p>
      )}

      <div className="mt-[1.5cqw] flex min-h-0 flex-1 w-full items-center justify-center">
        {image && (
          <SlideImage
            src={assetUrl(image.asset, image.variant, segment)}
            name={image.asset}
          />
        )}
      </div>

      {slide.type === "sequence" && slide.steps && slide.steps.length > 1 && (
        <div className="mt-[1.2cqw] flex items-center justify-center gap-[0.7cqw]">
          {slide.steps.map((_, i) => (
            <span
              key={i}
              className={[
                "size-[0.9cqw] rounded-full transition-colors",
                i === stepIndex ? "bg-bm-white" : "bg-bm-white/40",
              ].join(" ")}
            />
          ))}
        </div>
      )}
    </div>
  )
}
