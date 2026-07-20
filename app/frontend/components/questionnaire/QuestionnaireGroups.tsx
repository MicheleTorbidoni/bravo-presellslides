import type { ReactNode } from "react"
import { ExtraField, type FieldValue } from "@/components/questionnaire/ExtraField"
import { isRef, isVisible } from "./helpers"
import type { Answers, Qual, Questionnaire } from "./types"

// Renders every group of a questionnaire (already scoped to one phase by the
// caller): each group's title, then its items in order. A `ref` item is handed off
// to `renderRef` (the caller resolves it against the decision tree, with its own
// key) — omitted entirely when `renderRef` isn't supplied, since a phase with no
// decision-tree questions (Questionario B) never has ref items anyway. Extra
// fields render via the shared `ExtraField`. `onlyCriticality` filters every group
// to its ref items only; `isVisible` still governs field-level visible_if.
export function QuestionnaireGroups({
  questionnaire,
  qual,
  answers,
  onlyCriticality,
  onQualChange,
  renderRef,
}: {
  questionnaire: Questionnaire
  qual: Qual
  answers: Answers
  onlyCriticality: boolean
  onQualChange: (field: string, value: FieldValue) => void
  renderRef?: (ref: string) => ReactNode
}) {
  return (
    <div className="space-y-10">
      {questionnaire.groups.map((group) => {
        const items = (
          onlyCriticality ? group.items.filter(isRef) : group.items
        ).filter((item) => isRef(item) || isVisible(item, qual, answers))
        if (items.length === 0) return null
        return (
          <section key={group.title}>
            <h2>{group.title}</h2>
            <div className="mt-4 space-y-4">
              {items.map((item) =>
                isRef(item) ? (
                  (renderRef?.(item.ref) ?? null)
                ) : (
                  <div
                    key={item.field}
                    className="rounded-md border border-hairline bg-surface p-5"
                  >
                    <ExtraField
                      def={item}
                      value={qual[item.field]}
                      onChange={(v) => onQualChange(item.field, v)}
                    />
                  </div>
                ),
              )}
            </div>
          </section>
        )
      })}
    </div>
  )
}
