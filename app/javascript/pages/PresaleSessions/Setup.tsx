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
import { Checkbox } from "@/components/ui/checkbox"
import { Badge } from "@/components/ui/badge"
import { apiPatch } from "@/lib/api"
import { cn } from "@/lib/utils"

type Segment = { id: string; label: string }
type Criticality = { id: number; label: string }

type SessionDetail = {
  id: number
  company_name: string | null
  contact_name: string | null
  prospect_email: string | null
  segment: string | null
}

// A single criticality row: a drag handle (the only drag-initiating element, so the
// checkbox stays clickable), the enable/disable checkbox, the label, and the
// "suggested by prospect" badge.
function SortableCriticality({
  criticality,
  isOn,
  isSuggested,
  onToggle,
}: {
  criticality: Criticality
  isOn: boolean
  isSuggested: boolean
  onToggle: (id: number) => void
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
      {isSuggested && (
        <Badge tone="accent" className="shrink-0">
          Indicata dal prospect
        </Badge>
      )}
    </li>
  )
}

export default function PresaleSessionSetup({
  session,
  segments,
  criticalitiesBySegment,
  selectedCriticalities,
  criticalitiesOrder,
  suggested,
  showIntro: showIntroProp,
  showHub: showHubProp,
}: {
  session: SessionDetail
  segments: Segment[]
  criticalitiesBySegment: Record<string, Criticality[]>
  selectedCriticalities: number[]
  criticalitiesOrder: number[]
  suggested: number[]
  showIntro: boolean
  showHub: boolean
}) {
  const [companyName, setCompanyName] = useState(session.company_name ?? "")
  const [contactName, setContactName] = useState(session.contact_name ?? "")
  const [segment, setSegment] = useState<string | null>(session.segment)
  const [selected, setSelected] = useState<number[]>(selectedCriticalities)
  const [order, setOrder] = useState<number[]>(criticalitiesOrder)
  const [showIntro, setShowIntro] = useState(showIntroProp)
  const [showHub, setShowHub] = useState(showHubProp)
  const [showError, setShowError] = useState(false)

  const url = `/presale_sessions/${session.id}`

  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  )

  // Criticalities available for the currently-selected segment, indexed for lookup,
  // and resolved in the operator's chosen order (any segment criticality missing
  // from `order` is appended so nothing disappears from the list).
  const segmentCriticalities = segment
    ? (criticalitiesBySegment[segment] ?? [])
    : []
  const byId = new Map(segmentCriticalities.map((c) => [c.id, c]))
  const orderedCriticalities = [
    ...order.filter((id) => byId.has(id)),
    ...segmentCriticalities.map((c) => c.id).filter((id) => !order.includes(id)),
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
        show_intro: showIntro,
        show_hub: showHub,
      })
    }, 400)
    return () => clearTimeout(timer)
  }, [companyName, contactName, segment, selected, order, showIntro, showHub, url])

  // Switching segment changes which criticalities exist, so reset both the selection
  // and the order to the new segment's full set in default order (the "all enabled by
  // default" rule) — any previous choice referred to a different segment and would
  // otherwise leave stale ids.
  function pickSegment(segId: string) {
    const ids = (criticalitiesBySegment[segId] ?? []).map((c) => c.id)
    setSegment(segId)
    setSelected(ids)
    setOrder(ids)
    setShowError(false)
  }

  function toggleCriticality(id: number) {
    setSelected((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
    )
    setShowError(false)
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
                  {orderedCriticalities.map((c) => (
                    <SortableCriticality
                      key={c.id}
                      criticality={c}
                      isOn={selected.includes(c.id)}
                      isSuggested={suggested.includes(c.id)}
                      onToggle={toggleCriticality}
                    />
                  ))}
                </ul>
              </SortableContext>
            </DndContext>
            {showError && segment && selected.length === 0 && (
              <p className="mt-2 text-xs text-danger-display">
                Abilita almeno una criticità per continuare.
              </p>
            )}

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
