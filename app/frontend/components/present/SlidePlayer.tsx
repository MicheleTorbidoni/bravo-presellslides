// Prospect-facing 16:9 slide player. Autonomous UI — no template design system,
// raw Tailwind only. Purely presentational: navigation state and keyboard handling
// live in Present.tsx (which binds captured questions to the current step); this
// component just renders the current step and its active phase.
//
// File-driven model: a criticality is an ordered list of steps; each step has a
// title/body (overlay, from config) and 1..N phases shown in sequence, each a
// bitmap or (M19) a minivideo. The phases are already resolved server-side
// (token > segment > shared) — see ContentConfig.steps_for — so this component
// just displays `step.phases[phaseIndex]`.
import { useEffect, useRef, useState } from "react"
import { PlayCircle } from "lucide-react"
import { Stage } from "./Stage"
import { Logo } from "./Logo"

// One phase of a step, resolved server-side from the file name
// (C<NN>-step<Y>[-<token>][.f<Z>][.audio].<png|mp4>). `audio` is true only for a
// spoken .audio.mp4 video; every other video is muted and loops.
export type Phase = {
  url: string
  kind: "image" | "video"
  audio: boolean
}

export type Step = {
  id: string
  title: string | null
  body: string | null
  phases: Phase[]
  // M18: the synthetic final step of a criticality's flow. Present only on that
  // step — undefined/null on every image step and on the intro, which never
  // carries a video. embed_url is null when the configured video doesn't
  // resolve to a known embed (see ContentConfig.video_url_for/VideoEmbed.url).
  video?: { embed_url: string | null } | null
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

// Labelled grey dashed-box placeholder shared by SlideImage (missing bitmap),
// SlideVideo (minivideo that fails to load) and VideoSlide (video that doesn't
// resolve to a known embed).
function MissingPlaceholder({ label }: { label: string }) {
  return (
    <div className="flex h-full w-full items-center justify-center rounded-xl border border-dashed border-bm-white/40 bg-bm-white/10">
      <span className="px-4 text-center font-mono text-[1.1cqw] text-bm-white/70">
        {label}
      </span>
    </div>
  )
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
    return <MissingPlaceholder label={name} />
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

// M19: a step/phase minivideo, autoplaying inline. Distinct from VideoSlide (M18's
// final YouTube/Vimeo embed). Mounted with key={url} by StepMedia, so changing
// step or phase unmounts the previous <video> — playback and audio stop with it.
// Muted videos (the default) loop until the operator advances. Spoken (.audio)
// videos play once with sound and rest on their last frame; if the browser
// refuses the unmuted start (autoplay policy — the recent click/→ usually
// suffices, but it isn't guaranteed), a button lets the operator start it.
function SlideVideo({ phase, name }: { phase: Phase; name: string }) {
  const ref = useRef<HTMLVideoElement>(null)
  const [failed, setFailed] = useState(false)
  const [blocked, setBlocked] = useState(false)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    // React doesn't reliably reflect the `muted` prop onto the element, and
    // browsers only honour muted autoplay when the property is actually set.
    el.muted = !phase.audio
    el.defaultMuted = !phase.audio
    el.play().catch((error: unknown) => {
      // AbortError = interrupted by unmount/navigation, not an autoplay refusal.
      if (error instanceof DOMException && error.name === "AbortError") return
      setBlocked(true)
    })
  }, [phase.audio])

  if (failed) {
    return <MissingPlaceholder label={name} />
  }

  return (
    <div className="relative flex h-full w-full items-center justify-center">
      <video
        ref={ref}
        src={phase.url}
        autoPlay
        playsInline
        preload="auto"
        muted={!phase.audio}
        loop={!phase.audio}
        data-audio={phase.audio ? "true" : "false"}
        onError={() => setFailed(true)}
        className="h-full w-full object-contain"
      />
      {blocked && (
        <button
          type="button"
          aria-label="Avvia il video con audio"
          onClick={(e) => {
            // Don't also trigger the stage's onAdvanceClick.
            e.stopPropagation()
            const el = ref.current
            if (!el) return
            el.muted = false
            void el.play().then(() => setBlocked(false)).catch(() => {})
          }}
          className="group absolute inset-0 flex items-center justify-center"
        >
          <span className="absolute inset-0 bg-black/30 transition group-hover:bg-black/45" />
          <PlayCircle
            className="relative h-[6cqw] w-[6cqw] text-bm-white drop-shadow-lg"
            strokeWidth={1.5}
          />
        </button>
      )}
    </div>
  )
}

// Renders the current phase as a bitmap or a minivideo.
function StepMedia({ phase, name }: { phase: Phase | undefined; name: string }) {
  if (phase?.kind === "video") {
    return <SlideVideo key={phase.url} phase={phase} name={name} />
  }
  return <SlideImage src={phase?.url} name={name} />
}

// Warms the browser cache with the next phase/step while the current one is on
// screen, so it shows (and a video starts) without waiting. Assets are served
// with a long immutable Cache-Control, so the real element then hits the cache.
// Runs only in an effect — never during SSR.
function usePreload(phase: Phase | null | undefined) {
  const url = phase?.url
  const kind = phase?.kind
  useEffect(() => {
    if (!url) return
    if (kind === "video") {
      const video = document.createElement("video")
      video.muted = true
      video.preload = "auto"
      video.src = url
      video.load()
      return () => {
        // Release the element (and its pending download) when moving on.
        video.removeAttribute("src")
        video.load()
      }
    }
    const img = new Image()
    img.src = url
  }, [url, kind])
}

// Extracts the YouTube video id from an already-resolved youtube-nocookie embed
// URL, so the click-to-play facade can show the real thumbnail without a network
// call (a plain <img>, not the YouTube API). Vimeo has no equivalent lightweight
// thumbnail — the facade falls back to a plain dark background for it.
function youtubeThumbnail(embedUrl: string): string | null {
  const match = embedUrl.match(/youtube-nocookie\.com\/embed\/([^/?]+)/)
  return match ? `https://i.ytimg.com/vi/${match[1]}/hqdefault.jpg` : null
}

// M18's final step: the criticality's deep-dive video, click-to-play (no
// autoplay). Three states: no valid embed → placeholder; embed but not started →
// a clickable facade (real YouTube thumbnail when available, a plain dark
// background for Vimeo) with a play icon; started → the actual embed, playing.
// Clicking the facade stops propagation so it doesn't also trigger the stage's
// onAdvanceClick — advancing stays bound to the rest of the stage / the → key.
function VideoSlide({ video }: { video: { embed_url: string | null } }) {
  const [started, setStarted] = useState(false)
  const [prevUrl, setPrevUrl] = useState(video.embed_url)
  if (video.embed_url !== prevUrl) {
    setPrevUrl(video.embed_url)
    setStarted(false)
  }

  if (!video.embed_url) {
    return <MissingPlaceholder label="Video non disponibile" />
  }

  if (started) {
    // mute=1 alongside autoplay=1: browsers only guarantee autoplay when muted —
    // an unmuted autoplay request on a freshly-mounted cross-origin iframe doesn't
    // reliably inherit the click that created it, and YouTube surfaces that failure
    // as a hard player error rather than a silent pause. Muted autoplay is
    // universally honoured, so the video starts immediately; the prospect can
    // unmute from YouTube's own control if they want sound.
    return (
      <iframe
        src={`${video.embed_url}?autoplay=1&mute=1`}
        title="Video di approfondimento"
        allow="autoplay; encrypted-media; picture-in-picture"
        allowFullScreen
        className="h-full w-full rounded-xl"
      />
    )
  }

  const thumbnail = youtubeThumbnail(video.embed_url)

  return (
    <button
      type="button"
      aria-label="Avvia il video"
      onClick={(e) => {
        e.stopPropagation()
        setStarted(true)
      }}
      className="group relative flex h-full w-full items-center justify-center overflow-hidden rounded-xl bg-black/60"
    >
      {thumbnail && (
        <img src={thumbnail} alt="" className="h-full w-full object-cover" />
      )}
      <span className="absolute inset-0 bg-black/30 transition group-hover:bg-black/45" />
      <PlayCircle
        className="relative h-[6cqw] w-[6cqw] text-bm-white drop-shadow-lg"
        strokeWidth={1.5}
      />
    </button>
  )
}

export function SlidePlayer({
  step,
  phaseIndex,
  companyName,
  contactName,
  onAdvanceClick,
  nextPhase,
}: {
  step: Step | null
  phaseIndex: number
  companyName: string | null
  contactName: string | null
  onAdvanceClick: () => void
  // The phase that the next advance will show, preloaded in the background.
  nextPhase?: Phase | null
}) {
  usePreload(nextPhase)

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
  // M18: the criticality's final step — fullscreen player, no title/body/dots.
  if (step.video) {
    return (
      <div className="flex h-full w-full items-center justify-center p-[4cqw]">
        <div className="aspect-video max-h-full w-full overflow-hidden rounded-xl">
          <VideoSlide video={step.video} />
        </div>
      </div>
    )
  }

  const title = step.title ? interpolate(step.title, companyName, contactName) : null
  const body = step.body ? interpolate(step.body, companyName, contactName) : null
  const phase = step.phases[phaseIndex]
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
        <StepMedia phase={phase} name={step.id} />
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
