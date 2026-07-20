import type { FieldDef } from "@/components/questionnaire/ExtraField"
import type { Answers, Qual, Questionnaire, QuestionnaireItem, RefItem } from "./types"

export function isRef(item: QuestionnaireItem): item is RefItem {
  return "ref" in item
}

// Evaluates a field's visibility condition. A condition can reference another extra
// field (`field`) or a decision-tree question by its ref id (`ref`, matched against
// the selected answer code). Fields without a condition, and the decision-tree refs
// themselves, are always visible. A value already entered in a field that later
// becomes hidden is kept (not cleared) — it reappears if the condition becomes true
// again.
export function isVisible(def: FieldDef, qual: Qual, answers: Answers): boolean {
  const cond = def.visible_if
  if (!cond) return true
  if ("ref" in cond) return answers[cond.ref] === cond.equals
  const current = qual[cond.field]
  if ("includes" in cond) {
    return Array.isArray(current) && current.includes(cond.includes)
  }
  return current === cond.equals
}

// Finds the single autosum field (a total that is the sum of listed count fields).
export function findAutosum(
  questionnaire: Questionnaire,
): { field: string; sources: string[] } | null {
  for (const group of questionnaire.groups) {
    for (const item of group.items) {
      if (!isRef(item) && item.autosum && item.autosum.length > 0) {
        return { field: item.field, sources: item.autosum }
      }
    }
  }
  return null
}

export function sumOf(qual: Qual, sources: string[]): number {
  return sources.reduce(
    (acc, f) => acc + (typeof qual[f] === "number" ? (qual[f] as number) : 0),
    0,
  )
}

export function anyFilled(qual: Qual, sources: string[]): boolean {
  return sources.some((f) => {
    const v = qual[f]
    return v != null && v !== ""
  })
}
