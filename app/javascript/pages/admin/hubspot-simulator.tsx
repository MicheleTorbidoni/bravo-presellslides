import { Head, Link, useForm, usePage } from "@inertiajs/react"
import { ArrowRight, CheckCircle2, Sparkles } from "lucide-react"
import { AdminShell } from "@/components/AdminShell"
import { Button } from "@/components/ui/button"
import type { PageProps } from "@/types/inertia"

type CreatedSession = {
  id: number
  company_name: string | null
  contact_name: string | null
  prospect_email: string | null
  prospect_role: string | null
  segment_label: string | null
  suggested: string[]
  hub_url: string
  setup_url: string
}

export default function HubspotSimulator({
  createdSession,
}: {
  createdSession: CreatedSession | null
}) {
  const { props } = usePage<PageProps>()
  const form = useForm({})
  const baseError = props.errors?.base

  return (
    <>
      <Head title="HubSpot Simulator">
        <meta
          name="description"
          content="Simula una prenotazione da HubSpot: genera dati placeholder e mette in scena il dialogo App↔HubSpot sui webhook reali firmati."
        />
        <meta property="og:title" content="HubSpot Simulator" />
        <meta
          property="og:description"
          content="Simula una prenotazione da HubSpot: genera dati placeholder e mette in scena il dialogo App↔HubSpot sui webhook reali firmati."
        />
      </Head>
      <AdminShell>
        <div className="border-b border-hairline pb-6">
          <h1>HubSpot Simulator</h1>
          <p className="mt-1 max-w-2xl">
            Genera dati placeholder e mette in scena l&apos;intero dialogo
            App↔HubSpot: firma e invia ai webhook reali la prenotazione e una
            selezione casuale di criticità. Nessuna scrittura diretta a database
            — è lo stesso round-trip firmato che farebbe il vero HubSpot.
          </p>
        </div>

        <div className="mt-6">
          <Button
            type="button"
            onClick={() => form.post("/admin/hubspot-simulator/simulate")}
            disabled={form.processing}
          >
            <Sparkles className="h-4 w-4" />
            {form.processing ? "Simulazione in corso…" : "Simula prenotazione da HubSpot"}
          </Button>
        </div>

        {props.flash?.notice && (
          <p className="mt-4 text-sm text-accent">{props.flash.notice}</p>
        )}
        {baseError && (
          <p className="mt-4 text-sm text-danger-display">{baseError}</p>
        )}

        {createdSession && (
          <div className="mt-6 rounded-md border border-hairline bg-page p-5">
            <div className="flex items-center gap-2 text-accent">
              <CheckCircle2 className="h-5 w-5" />
              <span className="text-sm font-medium">Sessione creata</span>
            </div>

            <dl className="mt-4 grid grid-cols-1 gap-x-8 gap-y-3 sm:grid-cols-2">
              <Field label="Azienda" value={createdSession.company_name} />
              <Field label="Contatto" value={createdSession.contact_name} />
              <Field label="Email" value={createdSession.prospect_email} />
              <Field label="Ruolo" value={createdSession.prospect_role} />
              <Field label="Segmento" value={createdSession.segment_label} />
              <Field
                label="Criticità suggerite"
                value={
                  createdSession.suggested.length > 0
                    ? createdSession.suggested.join(", ")
                    : "—"
                }
              />
            </dl>

            <div className="mt-5 flex flex-wrap gap-3">
              <Button asChild variant="secondary" size="sm">
                <Link href={createdSession.hub_url}>
                  Apri hub
                  <ArrowRight className="h-4 w-4" />
                </Link>
              </Button>
              <Button asChild variant="ghost" size="sm">
                <Link href={createdSession.setup_url}>Apri sessione</Link>
              </Button>
            </div>
          </div>
        )}
      </AdminShell>
    </>
  )
}

function Field({ label, value }: { label: string; value: string | null }) {
  return (
    <div>
      <dt className="text-xs text-ink-muted">{label}</dt>
      <dd className="mt-0.5 text-sm text-ink-body">{value || "—"}</dd>
    </div>
  )
}
