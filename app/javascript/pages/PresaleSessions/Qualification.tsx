import { useEffect, useRef, useState } from "react"
import { Head, router } from "@inertiajs/react"
import { AppShell } from "@/components/AppShell"
import { Button } from "@/components/ui/button"
import { apiPatch } from "@/lib/api"
import { QuestionnaireGroups } from "@/components/questionnaire/QuestionnaireGroups"
import { useAutosum } from "@/components/questionnaire/useAutosum"
import type { Qual, Questionnaire } from "@/components/questionnaire/types"

type SessionDetail = { id: number }

// Questionario B: reached from the presentation's closing screen ("Completa
// scheda"), once the call itself is essentially over. Only the phase-2
// qualification group (today: reduced "Azienda" — headcount/turnover) — no
// decision-tree questions here, so no gate: the final button is always enabled.
export default function PresaleSessionQualification({
  session,
  questionnaire,
  qualificationAnswers,
}: {
  session: SessionDetail
  questionnaire: Questionnaire
  qualificationAnswers: Qual | null
}) {
  const [qual, setQual] = useState<Qual>(() => ({ ...(qualificationAnswers ?? {}) }))
  const [saving, setSaving] = useState(false)

  const { setQualValue } = useAutosum(questionnaire, qualificationAnswers, qual, setQual)

  const url = `/presale_sessions/${session.id}`

  // Debounced auto-save, same pattern as Questionario A.
  const firstRender = useRef(true)
  useEffect(() => {
    if (firstRender.current) {
      firstRender.current = false
      return
    }
    const timer = setTimeout(() => {
      void apiPatch(url, { qualification_answers: qual })
    }, 400)
    return () => clearTimeout(timer)
  }, [url, qual])

  async function finish() {
    setSaving(true)
    await apiPatch(url, { qualification_answers: qual, status: "closed" })
    router.visit(`/presale_sessions/${session.id}/debrief`)
  }

  return (
    <>
      <Head title="Completa scheda">
        <meta
          name="description"
          content="Ultimi dettagli di qualificazione commerciale prima del riepilogo della call."
        />
        <meta property="og:title" content="Completa scheda" />
        <meta
          property="og:description"
          content="Ultimi dettagli di qualificazione commerciale prima del riepilogo della call."
        />
      </Head>
      <AppShell>
        <div className="border-b border-hairline pb-6">
          <h1>Completa scheda</h1>
          <p className="mt-1">
            Schermata interna — non mostrata al prospect. Ultimi dettagli prima
            di chiudere la call.
          </p>
        </div>

        <div className="mx-auto mt-8 max-w-2xl">
          <QuestionnaireGroups
            questionnaire={questionnaire}
            qual={qual}
            answers={{}}
            onlyCriticality={false}
            onQualChange={setQualValue}
          />

          <div className="mt-8 flex items-center justify-end border-t border-hairline pt-6">
            <Button size="lg" onClick={finish} disabled={saving}>
              Vai al riepilogo
            </Button>
          </div>
        </div>
      </AppShell>
    </>
  )
}
