import { useMemo, useState } from "react"
import { Head, router } from "@inertiajs/react"
import { ArrowLeft } from "lucide-react"
import { AppShell } from "@/components/AppShell"
import { Button } from "@/components/ui/button"
import { Radio } from "@/components/ui/radio"
import { cn } from "@/lib/utils"
import { apiPatch } from "@/lib/api"

type Answer = { label: string; code: string; next?: string }
type Question = { id: string; text: string; answers: Answer[] }
type Tree = { start: string; questions: Record<string, Question> }

type SessionDetail = { id: number }

type Answers = Record<string, string>

// Which questions are reachable — and therefore answerable — given the current
// answers. Walk from the start node: for an answered question follow only the
// chosen branch, for an unanswered one keep every branch open (so downstream
// questions stay enabled by default). A question is disabled only when a given
// answer diverts the path away from it (e.g. d1="Human Only" skips the IoT
// question). Fully generic over the tree shape.
function enabledIds(tree: Tree, answers: Answers): Set<string> {
  const enabled = new Set<string>()
  const queue = [tree.start]
  while (queue.length > 0) {
    const qid = queue.shift() as string
    if (enabled.has(qid)) continue
    enabled.add(qid)
    const q = tree.questions[qid]
    if (!q) continue
    const chosen = answers[qid]
    for (const a of q.answers) {
      if (chosen != null && a.code !== chosen) continue
      if (a.next) queue.push(a.next)
    }
  }
  return enabled
}

// Rebuild the operational profile by walking the tree from the start along the
// answered branches — never from the click order. Disabled/off-path answers are
// naturally skipped because the walk simply doesn't traverse them, so the token
// string stays deterministic. `complete` is true once the walk reaches a leaf
// (an answer with no `next`) with every question on the path answered.
function walkProfile(tree: Tree, answers: Answers): { codes: string[]; complete: boolean } {
  const codes: string[] = []
  let qid: string | undefined = tree.start
  while (qid) {
    const q: Question | undefined = tree.questions[qid]
    if (!q) return { codes, complete: false }
    const code: string | undefined = answers[qid]
    if (code == null) return { codes, complete: false }
    const a: Answer | undefined = q.answers.find((x: Answer) => x.code === code)
    if (!a) return { codes, complete: false }
    codes.push(code)
    if (!a.next) return { codes, complete: true }
    qid = a.next
  }
  return { codes, complete: false }
}

export default function PresaleSessionProfiling({
  session,
  tree,
}: {
  session: SessionDetail
  tree: Tree
}) {
  const [answers, setAnswers] = useState<Answers>({})
  const [saving, setSaving] = useState(false)

  const enabled = useMemo(() => enabledIds(tree, answers), [tree, answers])
  const { codes, complete } = useMemo(() => walkProfile(tree, answers), [tree, answers])

  // Fixed display order = the authoring order of the tree, so the layout is stable
  // regardless of what's been answered.
  const questionIds = Object.keys(tree.questions)

  function select(questionId: string, code: string) {
    setAnswers((prev) => ({ ...prev, [questionId]: code }))
  }

  async function finish() {
    if (!complete) return
    setSaving(true)
    await apiPatch(`/presale_sessions/${session.id}`, {
      operational_profile: codes.join("-"),
    })
    // Straight into the presentation: the result/summary screen is now shown only
    // at the end (after the operator presses C → Closing → "Vai al riepilogo").
    router.visit(`/presale_sessions/${session.id}/present`)
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
              Schermata interna — non mostrata al prospect. Rispondi alle
              domande, poi prosegui.
            </p>
          </div>
          <Button
            variant="ghost"
            onClick={() => router.visit(`/presale_sessions/${session.id}/setup`)}
            disabled={saving}
          >
            <ArrowLeft className="h-4 w-4" />
            Indietro
          </Button>
        </div>

        <div className="mx-auto mt-10 max-w-2xl space-y-4">
          {questionIds.map((qid) => {
            const q = tree.questions[qid]
            const isEnabled = enabled.has(qid)
            return (
              <fieldset
                key={qid}
                disabled={!isEnabled || saving}
                className={cn(
                  "rounded-md border border-hairline bg-surface p-5 transition-opacity",
                  !isEnabled && "opacity-50",
                )}
              >
                <legend>{q.text}</legend>
                <div className="mt-4 flex flex-col gap-2.5">
                  {q.answers.map((a) => {
                    const selected = answers[qid] === a.code
                    return (
                      <label
                        key={a.code}
                        className={cn(
                          "flex cursor-pointer items-center gap-3 rounded-md border px-4 py-3 text-sm font-normal text-ink-body transition-colors",
                          selected
                            ? "border-accent/40 bg-accent/5"
                            : "border-hairline bg-page hover:bg-surface",
                          !isEnabled && "cursor-not-allowed",
                        )}
                      >
                        <Radio
                          name={qid}
                          value={a.code}
                          checked={selected}
                          disabled={!isEnabled || saving}
                          onChange={() => select(qid, a.code)}
                        />
                        {a.label}
                      </label>
                    )
                  })}
                </div>
              </fieldset>
            )
          })}

          <div className="flex justify-end pt-2">
            <Button size="lg" onClick={finish} disabled={!complete || saving}>
              Avanti
            </Button>
          </div>
        </div>
      </AppShell>
    </>
  )
}
