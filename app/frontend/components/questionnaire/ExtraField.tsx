import { Input } from "@/components/ui/input"
import { Checkbox } from "@/components/ui/checkbox"
import { Radio, RadioGroup } from "@/components/ui/radio"
import { Textarea } from "@/components/ui/textarea"

export type FieldType =
  | "multi_select"
  | "text"
  | "integer"
  | "currency"
  | "percentage"
  | "boolean"
  | "textarea"

export type FieldValue = string | number | boolean | string[] | null | undefined

// Visibility conditions are authored in questionnaire.json now, but the hide/show
// logic itself is M16 — M15 keeps every field visible. Kept in the type so the
// config parses cleanly.
export type VisibleIf =
  | { field: string; includes: string }
  | { field: string; equals: boolean }
  // References a decision-tree question by its ref id; true when that question's
  // selected answer code equals the given value (e.g. d3 === "mrp").
  | { ref: string; equals: string }

export type FieldDef = {
  field: string
  label: string
  type: FieldType
  options?: string[]
  visible_if?: VisibleIf
  // When present, this field is the sum of the listed count fields (see the
  // autosum handling in Profiling.tsx). Only "total_people_count" uses it.
  autosum?: string[]
}

// Light, non-blocking validation for numeric fields: integers/currency must be
// >= 0, percentages within 0–100. Returns a message to show inline, or null.
function numericError(def: FieldDef, value: FieldValue): string | null {
  if (typeof value !== "number") return null
  if (def.type === "percentage") {
    if (value < 0 || value > 100) return "Inserisci un valore tra 0 e 100."
  } else if (def.type === "integer" || def.type === "currency") {
    if (value < 0) return "Inserisci un valore maggiore o uguale a 0."
    if (def.type === "integer" && !Number.isInteger(value))
      return "Inserisci un numero intero."
  }
  return null
}

// Renders a single sales-qualification field (an "extra" question — not part of the
// decision tree, no impact on tokens). The parent supplies the current value and an
// onChange; this component only knows how to draw one field per its type.
export function ExtraField({
  def,
  value,
  onChange,
}: {
  def: FieldDef
  value: FieldValue
  onChange: (value: FieldValue) => void
}) {
  const id = `qf-${def.field}`

  if (def.type === "multi_select") {
    const selected = Array.isArray(value) ? value : []
    return (
      <fieldset>
        <legend>{def.label}</legend>
        <div className="mt-3 flex flex-col gap-2.5">
          {(def.options ?? []).map((option) => {
            const checked = selected.includes(option)
            return (
              <label
                key={option}
                className="flex cursor-pointer items-center gap-3 text-sm font-normal text-ink-body"
              >
                <Checkbox
                  checked={checked}
                  onChange={() =>
                    onChange(
                      checked
                        ? selected.filter((o) => o !== option)
                        : [...selected, option],
                    )
                  }
                />
                {option}
              </label>
            )
          })}
        </div>
      </fieldset>
    )
  }

  if (def.type === "boolean") {
    return (
      <fieldset>
        <legend>{def.label}</legend>
        <RadioGroup orientation="horizontal" className="mt-3">
          <label className="flex cursor-pointer items-center gap-2 text-sm font-normal text-ink-body">
            <Radio
              name={id}
              checked={value === true}
              onChange={() => onChange(true)}
            />
            Sì
          </label>
          <label className="flex cursor-pointer items-center gap-2 text-sm font-normal text-ink-body">
            <Radio
              name={id}
              checked={value === false}
              onChange={() => onChange(false)}
            />
            No
          </label>
        </RadioGroup>
      </fieldset>
    )
  }

  if (def.type === "textarea") {
    return (
      <div className="space-y-2">
        <label htmlFor={id}>{def.label}</label>
        <Textarea
          id={id}
          rows={3}
          value={typeof value === "string" ? value : ""}
          onChange={(e) => onChange(e.target.value)}
        />
      </div>
    )
  }

  // Numeric-ish and plain text share the Input; currency/percentage add an adornment.
  const isNumber =
    def.type === "integer" ||
    def.type === "currency" ||
    def.type === "percentage"
  const stringValue =
    value === null || value === undefined ? "" : String(value)

  function handleChange(raw: string) {
    if (!isNumber) {
      onChange(raw)
      return
    }
    if (raw === "") {
      onChange(null)
      return
    }
    const parsed = Number(raw)
    onChange(Number.isNaN(parsed) ? null : parsed)
  }

  const error = numericError(def, value)

  const control = (
    <Input
      id={id}
      type={isNumber ? "number" : "text"}
      inputMode={isNumber ? "decimal" : undefined}
      min={isNumber ? 0 : undefined}
      max={def.type === "percentage" ? 100 : undefined}
      step={def.type === "integer" ? 1 : undefined}
      aria-invalid={error ? true : undefined}
      aria-describedby={error ? `${id}-error` : undefined}
      value={stringValue}
      onChange={(e) => handleChange(e.target.value)}
      className={
        def.type === "currency"
          ? "pl-7"
          : def.type === "percentage"
            ? "pr-8"
            : undefined
      }
    />
  )

  return (
    <div className="space-y-2">
      <label htmlFor={id}>{def.label}</label>
      {def.type === "currency" ? (
        <div className="relative">
          <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-sm text-ink-muted">
            €
          </span>
          {control}
        </div>
      ) : def.type === "percentage" ? (
        <div className="relative">
          {control}
          <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-sm text-ink-muted">
            %
          </span>
        </div>
      ) : (
        control
      )}
      {error && (
        <p id={`${id}-error`} className="text-xs text-danger-display">
          {error}
        </p>
      )}
    </div>
  )
}
