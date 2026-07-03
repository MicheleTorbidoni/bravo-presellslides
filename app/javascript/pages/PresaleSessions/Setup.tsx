import { useEffect, useRef, useState } from "react"
import { Head, router } from "@inertiajs/react"
import { ArrowRight, Check, GripVertical, X } from "lucide-react"
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core"
import {
  SortableContext,
  arrayMove,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable"
import { CSS } from "@dnd-kit/utilities"
import { AppShell } from "@/components/AppShell"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select } from "@/components/ui/select"
import { Checkbox } from "@/components/ui/checkbox"
import { Badge } from "@/components/ui/badge"
import { apiPatch } from "@/lib/api"
import { cn } from "@/lib/utils"

type Segment = { id: string; label: string }
type Criticality = { id: number; label: string }
type Extra = { id: number; segment: string }

type SessionDetail = {
  id: number
  company_name: string | null
  contact_name: string | null
  prospect_email: string | null
  segment: string | null
}

// A single criticality row: a drag handle (the only drag-initiating element, so the
// checkbox stays clickable), the enable/disable checkbox, the label, and the
// "suggested by prospect" badge. Extra criticalities borrowed from another segment
// pass `sourceSegmentLabel` (shows an origin badge) and `onRemove` (shows a remove
// "X"); plain segment rows omit both and stay unchanged.
function SortableCriticality({
  criticality,
  isOn,
  isSuggested,
  onToggle,
  sourceSegmentLabel,
  onRemove,
}: {
  criticality: Criticality
  isOn: boolean
  isSuggested: boolean
  onToggle: (id: number) => void
  sourceSegmentLabel?: string
  onRemove?: (id: number) => void
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: criticality.id })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  }

  return (
    <li
      ref={setNodeRef}
      style={style}
      className={cn(
        "flex items-center justify-between gap-3 rounded-md border px-4 py-3 text-sm text-ink-body transition-colors",
        isOn ? "border-accent/40 bg-accent/5" : "border-hairline bg-page",
        isDragging && "relative z-10 shadow-lg",
      )}
    >
      <span className="flex items-center gap-3">
        <button
          type="button"
          aria-label="Trascina per riordinare"
          className="-ml-1 cursor-grab touch-none text-ink-muted transition-colors hover:text-ink-body active:cursor-grabbing"
          {...attributes}
          {...listeners}
        >
          <GripVertical className="h-4 w-4" />
        </button>
        <label className="flex cursor-pointer items-center gap-3 font-normal text-ink-body">
          <Checkbox checked={isOn} onChange={() => onToggle(criticality.id)} />
          <span>{criticality.label}</span>
        </label>
      </span>
      <span className="flex shrink-0 items-center gap-2">
        {isSuggested && <Badge tone="accent">Indicata dal prospect</Badge>}
        {sourceSegmentLabel && <Badge tone="neutral">{sourceSegmentLabel}</Badge>}
        {onRemove && (
          <button
            type="button"
            aria-label={`Rimuovi ${criticality.label}`}
            onClick={() => onRemove(criticality.id)}
            className="text-ink-muted transition-colors hover:text-danger-display"
          >
            <X className="h-4 w-4" />
          </button>
        )}
      </span>
    </li>
  )
}

// The "add from another segment" panel: pick a segment other than the prospect's,
// then add any of its criticalities that aren't already in the current subset or
// already added. Criticalities already present are shown disabled with why.
function AddFromSegmentPanel({
  segments,
  currentSegment,
  criticalitiesBySegment,
  segmentIds,
  extraIds,
  pickerSegment,
  onPickSegment,
  onAdd,
}: {
  segments: Segment[]
  currentSegment: string
  criticalitiesBySegment: Record<string, Criticality[]>
  segmentIds: Set<number>
  extraIds: Set<number>
  pickerSegment: string
  onPickSegment: (segId: string) => void
  onAdd: (id: number, segId: string) => void
}) {
  const otherSegments = segments.filter((s) => s.id !== currentSegment)
  const list = pickerSegment ? (criticalitiesBySegment[pickerSegment] ?? []) : []

  return (
    <div className="mt-6 rounded-md border border-hairline bg-surface p-4">
      <h3 className="text-sm font-semibold text-ink-display">
        Aggiungi criticità da un altro segmento
      </h3>
      <p className="mt-1 text-sm text-ink-muted">
        Porta in questa call una criticità presa da un segmento diverso da quello
        del prospect. Vale solo per questa sessione.
      </p>
      <div className="mt-3 max-w-xs">
        <Select
          aria-label="Scegli un altro segmento"
          value={pickerSegment}
          onChange={(e) => onPickSegment(e.target.value)}
        >
          <option value="">Scegli un segmento…</option>
          {otherSegments.map((s) => (
            <option key={s.id} value={s.id}>
              {s.label}
            </option>
          ))}
        </Select>
      </div>

      {pickerSegment && (
        <ul className="mt-3 flex flex-col gap-2">
          {list.map((c) => {
            const alreadyInSubset = segmentIds.has(c.id)
            const alreadyExtra = extraIds.has(c.id)
            const disabled = alreadyInSubset || alreadyExtra
            return (
              <li
                key={c.id}
                className="flex items-center justify-between gap-3 rounded-md border border-hairline bg-page px-4 py-2.5 text-sm text-ink-body"
              >
                <span>{c.label}</span>
                {disabled ? (
                  <span className="shrink-0 text-xs text-ink-muted">
                    {alreadyInSubset ? "Già presente" : "Aggiunta"}
                  </span>
                ) : (
                  <Button
                    variant="secondary"
                    size="sm"
                    className="shrink-0"
                    onClick={() => onAdd(c.id, pickerSegment)}
                  >
                    Aggiungi
                  </Button>
                )}
              </li>
            )
          })}
        </ul>
      )}
    </div>
  )
}

export default function PresaleSessionSetup({
  session,
  segments,
  criticalitiesBySegment,
  selectedCriticalities,
  criticalitiesOrder,
  extraCriticalities,
  suggested,
  showIntro: showIntroProp,
  showHub: showHubProp,
}: {
  session: SessionDetail
  segments: Segment[]
  criticalitiesBySegment: Record<string, Criticality[]>
  selectedCriticalities: number[]
  criticalitiesOrder: number[]
  extraCriticalities: Extra[]
  suggested: number[]
  showIntro: boolean
  showHub: boolean
}) {
  const [companyName, setCompanyName] = useState(session.company_name ?? "")
  const [contactName, setContactName] = useState(session.contact_name ?? "")
  const [segment, setSegment] = useState<string | null>(session.segment)
  const [selected, setSelected] = useState<number[]>(selectedCriticalities)
  const [order, setOrder] = useState<number[]>(criticalitiesOrder)
  const [extras, setExtras] = useState<Extra[]>(extraCriticalities)
  const [pickerSegment, setPickerSegment] = useState("")
  const [showIntro, setShowIntro] = useState(showIntroProp)
  const [showHub, setShowHub] = useState(showHubProp)
  const [showError, setShowError] = useState(false)

  const segmentLabelById = new Map(segments.map((s) => [s.id, s.label]))

  const url = `/presale_sessions/${session.id}`

  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  )

  // Criticalities available for the currently-selected segment, indexed for lookup.
  const segmentCriticalities = segment
    ? (criticalitiesBySegment[segment] ?? [])
    : []
  const segmentIds = new Set(segmentCriticalities.map((c) => c.id))

  // Extra criticalities borrowed from other segments, resolved against their origin
  // segment's list (skip any that no longer exist there), carrying that origin.
  const resolvedExtras = extras.flatMap((e) => {
    const crit = (criticalitiesBySegment[e.segment] ?? []).find((c) => c.id === e.id)
    return crit ? [{ criticality: crit, segment: e.segment }] : []
  })
  const extraById = new Map(resolvedExtras.map((r) => [r.criticality.id, r]))

  // The combined list — segment subset plus extras — indexed for lookup and resolved
  // in the operator's chosen order (any id missing from `order` is appended so
  // nothing disappears from the list). Both kinds share `order`/`selected`.
  const byId = new Map<number, Criticality>([
    ...segmentCriticalities.map((c) => [c.id, c] as const),
    ...resolvedExtras.map((r) => [r.criticality.id, r.criticality] as const),
  ])
  const orderedCriticalities = [
    ...order.filter((id) => byId.has(id)),
    ...[...byId.keys()].filter((id) => !order.includes(id)),
  ].map((id) => byId.get(id)!)

  // Debounced auto-save: persist the prospect data, criticality selection and the
  // intro toggle as the operator edits them, so nothing is lost mid-setup.
  const firstRender = useRef(true)
  useEffect(() => {
    if (firstRender.current) {
      firstRender.current = false
      return
    }
    const timer = setTimeout(() => {
      void apiPatch(url, {
        company_name: companyName,
        contact_name: contactName,
        segment,
        selected_criticalities: selected,
        criticalities_order: order,
        extra_criticalities: extras,
        show_intro: showIntro,
        show_hub: showHub,
      })
    }, 400)
    return () => clearTimeout(timer)
  }, [
    companyName,
    contactName,
    segment,
    selected,
    order,
    extras,
    showIntro,
    showHub,
    url,
  ])

  // Switching segment changes which criticalities exist, so reset both the selection
  // and the order to the new segment's full set in default order (the "all enabled by
  // default" rule) — any previous choice referred to a different segment and would
  // otherwise leave stale ids.
  function pickSegment(segId: string) {
    const ids = (criticalitiesBySegment[segId] ?? []).map((c) => c.id)
    setSegment(segId)
    setSelected(ids)
    setOrder(ids)
    // Extras belong to the previous segment's call; a new segment starts clean.
    setExtras([])
    setPickerSegment("")
    setShowError(false)
  }

  function toggleCriticality(id: number) {
    setSelected((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
    )
    setShowError(false)
  }

  // Bring a criticality from another segment into this call: it joins the list
  // enabled and at the end of the order, exactly like a normal one.
  function addExtra(id: number, segId: string) {
    setExtras((prev) => [...prev, { id, segment: segId }])
    setSelected((prev) => (prev.includes(id) ? prev : [...prev, id]))
    setOrder((prev) => (prev.includes(id) ? prev : [...prev, id]))
    setShowError(false)
  }

  function removeExtra(id: number) {
    setExtras((prev) => prev.filter((e) => e.id !== id))
    setSelected((prev) => prev.filter((x) => x !== id))
    setOrder((prev) => prev.filter((x) => x !== id))
  }

  // Reorder the criticality list: dropping a row moves it within `order`, which
  // drives both this list and the presentation sequence.
  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    if (!over || active.id === over.id) return
    setOrder((prev) => {
      const ids = orderedCriticalities.map((c) => c.id)
      const base = prev.length === ids.length ? prev : ids
      const oldIndex = base.indexOf(Number(active.id))
      const newIndex = base.indexOf(Number(over.id))
      if (oldIndex === -1 || newIndex === -1) return prev
      return arrayMove(base, oldIndex, newIndex)
    })
  }

  async function continueToProfiling() {
    if (!segment || selected.length === 0) {
      setShowError(true)
      return
    }
    await apiPatch(url, {
      company_name: companyName,
      contact_name: contactName,
      segment,
      selected_criticalities: selected,
      criticalities_order: order,
      extra_criticalities: extras,
      show_intro: showIntro,
      show_hub: showHub,
    })
    router.visit(`/presale_sessions/${session.id}/profiling`)
  }

  return (
    <>
      <Head title="Nuova sessione — Setup">
        <meta
          name="description"
          content="Inserisci i dati del prospect e scegli il segmento industriale per avviare la profilazione."
        />
        <meta property="og:title" content="Nuova sessione — Setup" />
        <meta
          property="og:description"
          content="Inserisci i dati del prospect e scegli il segmento industriale per avviare la profilazione."
        />
      </Head>
      <AppShell>
        <div className="border-b border-hairline pb-6">
          <h1>Setup sessione</h1>
          <p className="mt-1">
            Dati del prospect e segmento industriale. Queste schermate non vengono
            mostrate al prospect.
          </p>
        </div>

        <div className="mt-6 max-w-xl space-y-5">
          <div className="space-y-2">
            <label htmlFor="company_name">Nome azienda prospect</label>
            <Input
              id="company_name"
              value={companyName}
              onChange={(e) => setCompanyName(e.target.value)}
              autoFocus
            />
          </div>
          <div className="space-y-2">
            <label htmlFor="contact_name">Nome contatto prospect</label>
            <Input
              id="contact_name"
              value={contactName}
              onChange={(e) => setContactName(e.target.value)}
            />
          </div>
          {session.prospect_email && (
            <div className="space-y-2">
              <label htmlFor="prospect_email">Email prospect</label>
              <Input id="prospect_email" value={session.prospect_email} readOnly />
              <p className="text-xs text-ink-muted">
                Indicata dal prospect nella prenotazione HubSpot.
              </p>
            </div>
          )}
        </div>

        <div className="mt-8">
          <h2 className="text-base font-semibold text-ink-display">
            Segmento industriale
          </h2>
          <div className="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-3">
            {segments.map((seg) => {
              const isSelected = segment === seg.id
              return (
                <button
                  key={seg.id}
                  type="button"
                  onClick={() => pickSegment(seg.id)}
                  aria-pressed={isSelected}
                  className={cn(
                    "flex items-center justify-between gap-2 rounded-md border px-4 py-3 text-left text-sm transition-colors",
                    isSelected
                      ? "border-accent bg-accent-faded text-accent-display"
                      : "border-hairline text-ink-body hover:bg-surface",
                  )}
                >
                  <span>{seg.label}</span>
                  {isSelected && <Check className="h-4 w-4 shrink-0" />}
                </button>
              )
            })}
          </div>
          {showError && !segment && (
            <p className="mt-2 text-xs text-danger-display">
              Seleziona un segmento per continuare.
            </p>
          )}
        </div>

        {segment && (
          <div className="mt-8 max-w-2xl">
            <h2 className="text-base font-semibold text-ink-display">
              Criticità da discutere
            </h2>
            <p className="mt-1 text-sm text-ink-muted">
              Abilita le criticità da presentare e trascinale per scegliere
              l'ordine.
              {suggested.length > 0 &&
                " Quelle contrassegnate sono già state indicate dal prospect."}
            </p>
            <DndContext
              sensors={sensors}
              collisionDetection={closestCenter}
              onDragEnd={handleDragEnd}
            >
              <SortableContext
                items={orderedCriticalities.map((c) => c.id)}
                strategy={verticalListSortingStrategy}
              >
                <ul className="mt-3 flex flex-col gap-2">
                  {orderedCriticalities.map((c) => {
                    const extra = extraById.get(c.id)
                    return (
                      <SortableCriticality
                        key={c.id}
                        criticality={c}
                        isOn={selected.includes(c.id)}
                        isSuggested={suggested.includes(c.id)}
                        onToggle={toggleCriticality}
                        sourceSegmentLabel={
                          extra
                            ? (segmentLabelById.get(extra.segment) ?? extra.segment)
                            : undefined
                        }
                        onRemove={extra ? removeExtra : undefined}
                      />
                    )
                  })}
                </ul>
              </SortableContext>
            </DndContext>
            {showError && segment && selected.length === 0 && (
              <p className="mt-2 text-xs text-danger-display">
                Abilita almeno una criticità per continuare.
              </p>
            )}

            <AddFromSegmentPanel
              segments={segments}
              currentSegment={segment}
              criticalitiesBySegment={criticalitiesBySegment}
              segmentIds={segmentIds}
              extraIds={new Set(extras.map((e) => e.id))}
              pickerSegment={pickerSegment}
              onPickSegment={setPickerSegment}
              onAdd={addExtra}
            />

            <div className="mt-5 flex flex-col gap-3">
              <label className="flex w-fit cursor-pointer items-center gap-3 text-sm font-normal text-ink-body">
                <Checkbox
                  checked={showIntro}
                  onChange={(e) => setShowIntro(e.target.checked)}
                />
                <span>Mostra l'introduzione all'inizio</span>
              </label>
              <label className="flex w-fit cursor-pointer items-center gap-3 text-sm font-normal text-ink-body">
                <Checkbox
                  checked={showHub}
                  onChange={(e) => setShowHub(e.target.checked)}
                />
                <span>Mostra l'hub tra le criticità</span>
              </label>
            </div>
          </div>
        )}

        <div className="mt-8 flex items-center justify-between border-t border-hairline pt-6">
          <Button
            variant="ghost"
            onClick={() => router.visit("/presale_sessions")}
          >
            <X className="h-4 w-4" />
            Chiudi
          </Button>
          <Button onClick={continueToProfiling}>
            Avanti
            <ArrowRight className="h-4 w-4" />
          </Button>
        </div>
      </AppShell>
    </>
  )
}
