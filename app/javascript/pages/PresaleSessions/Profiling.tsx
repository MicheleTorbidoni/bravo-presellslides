import { useEffect, useMemo, useRef, useState } from "react"
import { Head, router } from "@inertiajs/react"
import { ArrowLeft } from "lucide-react"
import { AppShell } from "@/components/AppShell"
import { Button } from "@/components/ui/button"
import { Radio } from "@/components/ui/radio"
import { Checkbox } from "@/components/ui/checkbox"
import { cn } from "@/lib/utils"
import { apiPatch } from "@/lib/api"
import {
  ExtraField,
  type FieldDef,
  type FieldValue,
} from "@/components/questionnaire/ExtraField"

type Answer = { label: string; code: string; next?: string }
type Question = { id: string; text: string; answers: Answer[] }
type Tree = { start: string; questions: Record<string, Question> }

type RefItem = { ref: string }
type QuestionnaireItem = RefItem | FieldDef
type QuestionnaireGroup = { title: string; items: QuestionnaireItem[] }
type Questionnaire = { groups: QuestionnaireGroup[] }

type SessionDetail = { id: number; operational_profile: string | null }

type Answers = Record<string, string>
type Qual = Record<string, FieldValue>

function isRef(item: QuestionnaireItem): item is RefItem {
  return "ref" in item
}

// Which questions are reachable — and therefore answerable — given the current
// answers. Walk from the start node: for an answered question follow only the
// chosen branch, for an unanswered one keep every branch open (so downstream
// questions stay enabled by default). A question is disabled only when a given
// answer diverts the path away from it. Fully generic over the tree shape.
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
// naturally skipped. `complete` is true once the walk reaches a leaf (an answer
// with no `next`) with every question on the path answered.
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

// Reconstruct the per-question answers map from a saved operational_profile string,
// used to restore the criticality radios on reload. Walks the tree consuming one
// token per question. (Answers given out of order before an unanswered upstream
// question aren't in the saved prefix and won't restore — an accepted edge case.)
function answersFromProfile(tree: Tree, profile: string): Answers {
  const result: Answers = {}
  if (!profile) return result
  let qid: string | undefined = tree.start
  for (const token of profile.split("-")) {
    if (!qid) break
    const q: Question | undefined = tree.questions[qid]
    if (!q) break
    const a: Answer | undefined = q.answers.find((x: Answer) => x.code === token)
    if (!a) break
    result[qid] = token
    qid = a.next
  }
  return result
}

export default function PresaleSessionProfiling({
  session,
  tree,
  questionnaire,
  qualificationAnswers,
}: {
  session: SessionDetail
  tree: Tree
  questionnaire: Questionnaire
  qualificationAnswers: Qual | null
}) {
  const [answers, setAnswers] = useState<Answers>(() =>
    answersFromProfile(tree, session.operational_profile ?? ""),
  )
  const [qual, setQual] = useState<Qual>(() => ({ ...(qualificationAnswers ?? {}) }))
  const [onlyCriticality, setOnlyCriticality] = useState(false)
  const [saving, setSaving] = useState(false)

  const enabled = useMemo(() => enabledIds(tree, answers), [tree, answers])
  const { codes, complete } = useMemo(() => walkProfile(tree, answers), [tree, answers])
  const profile = codes.join("-")

  // Debounced auto-save: persist the token profile and the qualification answers as
  // the operator edits, so nothing is lost if the call is interrupted. Mirrors the
  // Setup screen's auto-save. Both go through apiPatch (plain fetch → head :ok).
  const firstRender = useRef(true)
  useEffect(() => {
    if (firstRender.current) {
      firstRender.current = false
      return
    }
    const timer = setTimeout(() => {
      void apiPatch(`/presale_sessions/${session.id}`, {
        operational_profile: profile,
        qualification_answers: qual,
      })
    }, 400)
    return () => clearTimeout(timer)
  }, [session.id, profile, qual])

  function selectCriticality(questionId: string, code: string) {
    setAnswers((prev) => ({ ...prev, [questionId]: code }))
  }

  function setQualValue(field: string, value: FieldValue) {
    setQual((prev) => ({ ...prev, [field]: value }))
  }

  async function finish() {
    if (!complete) return
    setSaving(true)
    await apiPatch(`/presale_sessions/${session.id}`, {
      operational_profile: profile,
      qualification_answers: qual,
    })
    router.visit(`/presale_sessions/${session.id}/present`)
  }

  function renderCriticality(qid: string) {
    const q = tree.questions[qid]
    if (!q) return null
    const isEnabled = enabled.has(qid)
    return (
      <fieldset
        key={qid}
        disabled={!isEnabled || saving}
        className={cn(
          "rounded-md border border-accent/40 bg-accent/5 p-5 transition-opacity",
          !isEnabled && "opacity-60",
        )}
      >
        <legend>{q.text}</legend>
        <div className="mt-3 flex flex-col gap-2.5">
          {q.answers.map((a) => {
            const selected = answers[qid] === a.code
            return (
              <label
                key={a.code}
                className={cn(
                  "flex cursor-pointer items-center gap-3 rounded-md border px-4 py-3 text-sm font-normal text-ink-body transition-colors",
                  selected
                    ? "border-accent/60 bg-accent/10"
                    : "border-hairline bg-page hover:bg-surface",
                  !isEnabled && "cursor-not-allowed",
                )}
              >
                <Radio
                  name={qid}
                  value={a.code}
                  checked={selected}
                  disabled={!isEnabled || saving}
                  onChange={() => selectCriticality(qid, a.code)}
                />
                {a.label}
              </label>
            )
          })}
        </div>
      </fieldset>
    )
  }

  return (
    <>
      <Head title="Profilazione">
        <meta
          name="description"
          content="Decision tree di profilazione operativa del prospect e questionario di qualificazione commerciale."
        />
        <meta property="og:title" content="Profilazione" />
        <meta
          property="og:description"
          content="Decision tree di profilazione operativa del prospect e questionario di qualificazione commerciale."
        />
      </Head>
      <AppShell>
        <div className="flex items-center justify-between border-b border-hairline pb-6">
          <div>
            <h1>Profilazione</h1>
            <p className="mt-1">
              Schermata interna — non mostrata al prospect. Le domande in{" "}
              <span className="text-accent">evidenza</span> guidano le criticità;
              le altre servono al commerciale.
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

        <div className="mx-auto mt-8 max-w-2xl">
          <label className="flex cursor-pointer items-center gap-3 text-sm font-normal text-ink-body">
            <Checkbox
              checked={onlyCriticality}
              onChange={(e) => setOnlyCriticality(e.target.checked)}
            />
            Mostra solo domande per le criticità
          </label>

          <div className="mt-6 space-y-10">
            {questionnaire.groups.map((group) => {
              const items = onlyCriticality
                ? group.items.filter(isRef)
                : group.items
              if (items.length === 0) return null
              return (
                <section key={group.title}>
                  <h2>{group.title}</h2>
                  <div className="mt-4 space-y-4">
                    {items.map((item) =>
                      isRef(item) ? (
                        renderCriticality(item.ref)
                      ) : (
                        <div
                          key={item.field}
                          className="rounded-md border border-hairline bg-surface p-5"
                        >
                          <ExtraField
                            def={item}
                            value={qual[item.field]}
                            onChange={(v) => setQualValue(item.field, v)}
                          />
                        </div>
                      ),
                    )}
                  </div>
                </section>
              )
            })}
          </div>

          <div className="mt-10 flex justify-end">
            <Button size="lg" onClick={finish} disabled={!complete || saving}>
              Avanti
            </Button>
          </div>
        </div>
      </AppShell>
    </>
  )
}
