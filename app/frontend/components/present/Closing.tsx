// Fixed closing page, identical for every segment/profile — only the prospect's
// company/contact names change. Reached from anywhere via the `C` shortcut. The
// "Vai al debrief" handoff is a placeholder until the debrief lands in Milestone 6.
// Autonomous UI, raw Tailwind. Rendered inside the shared 16:9 Stage so it matches
// the hub and the slide flow shown to the prospect.
import { Stage } from "./Stage"

export function Closing({
  companyName,
  contactName,
  onBack,
}: {
  companyName: string | null
  contactName: string | null
  onBack: () => void
}) {
  const company = companyName?.trim() || "la tua azienda"
  const contact = contactName?.trim()

  return (
    <Stage>
      <div className="flex h-full w-full flex-col items-center justify-center px-8 py-16 text-center">
        <div className="w-full max-w-3xl">
        <h1 className="text-4xl font-semibold tracking-tight text-white sm:text-5xl">
          Grazie{contact ? `, ${contact}` : ""}.
        </h1>
        <p className="mt-6 text-lg text-slate-300">
          Abbiamo visto insieme come Bravo Manufacturing può supportare {company}.
          Ti invieremo un recap di quanto discusso.
        </p>

        <div className="mt-14 flex flex-col items-center gap-4">
          <button
            type="button"
            disabled
            title="Arriva nel Milestone 6"
            className="cursor-not-allowed rounded-full bg-white px-10 py-4 text-lg font-semibold text-slate-950 opacity-40"
          >
            Vai al debrief
          </button>
          <button
            type="button"
            onClick={onBack}
            className="text-sm text-slate-400 underline-offset-4 transition-colors hover:text-slate-200 hover:underline"
          >
            Torna all'hub
          </button>
        </div>
        </div>
      </div>
    </Stage>
  )
}
