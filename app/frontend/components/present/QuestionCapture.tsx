// Minimal question-capture overlay (Milestone 4). Opened with the `Q` shortcut
// during a slide flow; on confirm the question text is handed back to Present.tsx,
// which persists it (auto-save) bound to the current slide/criticality. Autonomous
// UI — no template design system, raw Tailwind only.
import { useState } from "react"

export function QuestionCapture({
  onSave,
  onCancel,
}: {
  onSave: (text: string) => void
  onCancel: () => void
}) {
  const [text, setText] = useState("")
  const canSave = text.trim().length > 0

  function save() {
    if (canSave) onSave(text.trim())
  }

  // Esc cancels; Cmd/Ctrl+Enter saves. The global keydown handler in Present.tsx
  // already ignores textarea targets, so the presentation shortcuts stay inert
  // while typing here.
  function onKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape") {
      e.preventDefault()
      onCancel()
    } else if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
      e.preventDefault()
      save()
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-bm-slate/70 px-6 font-bm">
      <div className="w-full max-w-2xl rounded-2xl bg-bm-white p-8 shadow-2xl">
        <h2 className="text-xl font-bold text-bm-slate">Cattura domanda</h2>
        <p className="mt-1 text-sm text-bm-slate/60">
          La domanda verrà salvata e collegata alla slide corrente.
        </p>

        {/* eslint-disable-next-line jsx-a11y/no-autofocus */}
        <textarea
          autoFocus
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={onKeyDown}
          rows={4}
          placeholder="Scrivi la domanda del prospect…"
          className="mt-5 w-full resize-none rounded-lg border border-bm-slate/25 bg-bm-white px-4 py-3 text-base text-bm-slate placeholder:text-bm-slate/40 focus:border-bm-green focus:outline-none"
        />

        <div className="mt-6 flex items-center justify-end gap-3">
          <button
            type="button"
            onClick={onCancel}
            className="rounded-full px-5 py-2.5 text-sm font-semibold text-bm-slate/70 transition-colors hover:text-bm-slate"
          >
            Annulla
          </button>
          <button
            type="button"
            onClick={save}
            disabled={!canSave}
            className="rounded-full bg-bm-green px-6 py-2.5 text-sm font-bold text-bm-white transition-opacity enabled:hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40"
          >
            Salva domanda
          </button>
        </div>
      </div>
    </div>
  )
}
