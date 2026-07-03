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

export type FieldDef = {
  field: string
  label: string
  type: FieldType
  options?: string[]
  visible_if?: VisibleIf
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

  const control = (
    <Input
      id={id}
      type={isNumber ? "number" : "text"}
      inputMode={isNumber ? "decimal" : undefined}
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
    </div>
  )
}
