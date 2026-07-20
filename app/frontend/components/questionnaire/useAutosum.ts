import { useEffect, useMemo, useState, type Dispatch, type SetStateAction } from "react"
import type { FieldValue } from "@/components/questionnaire/ExtraField"
import { anyFilled, findAutosum, sumOf } from "./helpers"
import type { Qual, Questionnaire } from "./types"

// Keeps the questionnaire's autosum field (today only "total_people_count", in the
// Azienda group) in sync with the sum of its source fields, unless the operator has
// typed their own value by hand — clearing it resumes auto-summing. Returns
// setQualValue, the single field-change handler pages should use: it transparently
// arms/disarms the override flag when the autosum field itself is edited, and is a
// plain qual update for every other field.
export function useAutosum(
  questionnaire: Questionnaire,
  qualificationAnswers: Qual | null,
  qual: Qual,
  setQual: Dispatch<SetStateAction<Qual>>,
) {
  const autosum = useMemo(() => findAutosum(questionnaire), [questionnaire])

  // Seed the override flag from the saved data: a saved total that differs from the
  // sum of its sources was entered by hand.
  const [totalOverridden, setTotalOverridden] = useState<boolean>(() => {
    if (!autosum) return false
    const initial = qualificationAnswers ?? {}
    const total = initial[autosum.field]
    if (total == null || total === "") return false
    return total !== sumOf(initial, autosum.sources)
  })

  // Recomputing from `prev` (not the closed-over qual) keeps it fresh; the equality
  // guard avoids redundant writes and re-render loops.
  const sourcesSig = autosum
    ? autosum.sources.map((f) => qual[f] ?? "").join("|")
    : ""
  useEffect(() => {
    if (!autosum || totalOverridden) return
    setQual((prev) => {
      const next = anyFilled(prev, autosum.sources)
        ? sumOf(prev, autosum.sources)
        : null
      // Treat undefined/null as equal so an empty total isn't written as a null key.
      const cur = prev[autosum.field] ?? null
      return cur === next ? prev : { ...prev, [autosum.field]: next }
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autosum, totalOverridden, sourcesSig])

  function setQualValue(field: string, value: FieldValue) {
    if (autosum && field === autosum.field) {
      setTotalOverridden(value != null && value !== "")
    }
    setQual((prev) => ({ ...prev, [field]: value }))
  }

  return { autosum, setQualValue }
}
