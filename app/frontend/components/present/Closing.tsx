// Fixed closing page, identical for every segment/profile — only the prospect's
// company/contact names change. Reached from anywhere via the `C` shortcut. The
// "Vai al debrief" button hands over to the internal debrief screen (Milestone 6).
// Autonomous UI, raw Tailwind, Bravo tokens (bm-*). Figma veste (node 67-32):
// slate stage, centred white title + body (Outfit), centred logo. Rendered inside
// the shared 16:9 Stage; sizes use cqw so they scale with the stage.
import { Stage } from "./Stage"
import { Logo } from "./Logo"

export function Closing({
  companyName,
  contactName,
  onBack,
  onDebrief,
}: {
  companyName: string | null
  contactName: string | null
  onBack: () => void
  onDebrief: () => void
}) {
  const company = companyName?.trim() || "la tua azienda"
  const contact = contactName?.trim()

  return (
    <Stage className="bg-bm-slate text-bm-white">
      <div className="flex h-full w-full flex-col items-center justify-center px-[8cqw] text-center">
        <h1 className="font-bm text-[4.6cqw] leading-[1.05] font-bold tracking-tight text-bm-white">
          Grazie{contact ? `, ${contact}` : ""}.
        </h1>
        <p className="mt-[1.6cqw] max-w-[70cqw] text-[1.9cqw] leading-snug text-bm-white/90">
          Abbiamo visto insieme come Bravo Manufacturing può supportare {company}.
          Ti invieremo un recap di quanto discusso.
        </p>

        <div className="mt-[4cqw] flex flex-col items-center gap-[1.4cqw]">
          <button
            type="button"
            onClick={onDebrief}
            className="-skew-x-12 bg-bm-white px-[2.8cqw] py-[1cqw] transition-colors hover:bg-bm-white/90"
          >
            <span className="block skew-x-12 text-[1.5cqw] font-bold tracking-tight text-bm-slate">
              Vai al debrief
            </span>
          </button>
          <button
            type="button"
            onClick={onBack}
            className="text-[1.1cqw] text-bm-white/70 underline-offset-4 transition-colors hover:text-bm-white hover:underline"
          >
            Torna all'hub
          </button>
        </div>
      </div>

      {/* Bravo Manufacturing logo — centred per Figma (node 67-32). */}
      <Logo
        variant="white"
        className="absolute bottom-[5cqw] left-1/2 h-[2.6cqw] w-auto -translate-x-1/2"
      />
    </Stage>
  )
}
