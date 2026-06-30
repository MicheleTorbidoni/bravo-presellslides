import { useState } from "react"
import { Head, router } from "@inertiajs/react"
import { ArrowLeft } from "lucide-react"
import { AppShell } from "@/components/AppShell"
import { Button } from "@/components/ui/button"
import { apiPatch } from "@/lib/api"

type Answer = { label: string; code: string; next?: string }
type Question = { id: string; text: string; answers: Answer[] }
type Tree = { start: string; questions: Record<string, Question> }

type SessionDetail = { id: number }

type Step = { questionId: string; code: string }

export default function PresaleSessionProfiling({
  session,
  tree,
}: {
  session: SessionDetail
  tree: Tree
}) {
  const [currentId, setCurrentId] = useState(tree.start)
  const [history, setHistory] = useState<Step[]>([])
  const [saving, setSaving] = useState(false)

  const question = tree.questions[currentId]

  async function answer(a: Answer) {
    const nextHistory = [...history, { questionId: currentId, code: a.code }]
    if (a.next) {
      setHistory(nextHistory)
      setCurrentId(a.next)
    } else {
      await finish(nextHistory)
    }
  }

  async function finish(finalHistory: Step[]) {
    setSaving(true)
    const operationalProfile = finalHistory.map((s) => s.code).join("-")
    await apiPatch(`/presale_sessions/${session.id}`, {
      operational_profile: operationalProfile,
    })
    // Straight into the presentation: the result/summary screen is now shown only
    // at the end (after the operator presses C → Closing → "Vai al riepilogo").
    router.visit(`/presale_sessions/${session.id}/present`)
  }

  function back() {
    if (history.length === 0) return
    const previous = history[history.length - 1]
    setHistory(history.slice(0, -1))
    setCurrentId(previous.questionId)
  }

  return (
    <>
      <Head title="Profilazione">
        <meta
          name="description"
          content="Decision tree di profilazione operativa del prospect."
        />
        <meta property="og:title" content="Profilazione" />
        <meta
          property="og:description"
          content="Decision tree di profilazione operativa del prospect."
        />
      </Head>
      <AppShell>
        <div className="flex items-center justify-between border-b border-hairline pb-6">
          <div>
            <h1>Profilazione</h1>
            <p className="mt-1">
              Schermata interna — non mostrata al prospect. Domanda{" "}
              {history.length + 1}.
            </p>
          </div>
          <Button variant="ghost" onClick={back} disabled={history.length === 0}>
            <ArrowLeft className="h-4 w-4" />
            Indietro
          </Button>
        </div>

        {question && (
          <div className="mx-auto mt-10 max-w-2xl text-center">
            <h2 className="text-xl font-semibold text-ink-display">
              {question.text}
            </h2>
            <div className="mt-8 flex flex-col gap-3">
              {question.answers.map((a) => (
                <Button
                  key={a.code}
                  variant="secondary"
                  size="lg"
                  disabled={saving}
                  onClick={() => answer(a)}
                >
                  {a.label}
                </Button>
              ))}
            </div>
          </div>
        )}
      </AppShell>
    </>
  )
}
