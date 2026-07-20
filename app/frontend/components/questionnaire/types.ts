import type { FieldDef, FieldValue } from "@/components/questionnaire/ExtraField"

export type Answer = { label: string; code: string; next?: string }
export type Question = { id: string; text: string; answers: Answer[] }
export type Tree = { start: string; questions: Record<string, Question> }

export type RefItem = { ref: string }
export type QuestionnaireItem = RefItem | FieldDef
export type QuestionnaireGroup = { title: string; items: QuestionnaireItem[] }
export type Questionnaire = { groups: QuestionnaireGroup[] }

// Decision-tree answers keyed by question id (e.g. { d1: "ho" }).
export type Answers = Record<string, string>
// Qualification answers keyed by field name — shared between Questionario A and
// Questionario B, since both write into the same qualification_answers jsonb.
export type Qual = Record<string, FieldValue>
