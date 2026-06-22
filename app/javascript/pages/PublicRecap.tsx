import { Head } from "@inertiajs/react"
import { CalendarPlus, ExternalLink } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"

type RecapCriticality = {
  id: number
  label: string
  discussed: boolean
  video_url: string | null
  embed_url: string | null
}

type Appointment = {
  display: string
  sales_name: string | null
  location: string | null
  ics_url: string
  google_url: string
}

export default function PublicRecap({
  session,
  topics,
  questions,
  criticalities,
  appointment,
}: {
  session: { company_name: string | null; contact_name: string | null }
  topics: string[]
  questions: string[]
  criticalities: RecapCriticality[]
  appointment: Appointment | null
}) {
  const company = session.company_name || "la vostra azienda"
  // M9: player embeddati inline. Le criticità discusse (con video) in evidenza,
  // il resto del subset come approfondimenti correlati. Un video va mostrato se
  // ha un embed riproducibile o, in fallback, un link esterno.
  const hasVideo = (c: RecapCriticality) => !!(c.embed_url || c.video_url)
  const discussedVideos = criticalities.filter((c) => c.discussed && hasVideo(c))
  const otherVideos = criticalities.filter((c) => !c.discussed && hasVideo(c))

  return (
    <>
      <Head title={`Riepilogo — ${company}`}>
        <meta name="robots" content="noindex" />
        <meta
          name="description"
          content="Il riepilogo personalizzato del tuo incontro con Bravo Manufacturing."
        />
        <meta property="og:title" content={`Riepilogo — ${company}`} />
        <meta
          property="og:description"
          content="Il riepilogo personalizzato del tuo incontro con Bravo Manufacturing."
        />
      </Head>

      <div className="min-h-screen bg-page px-4 py-12 text-ink-body sm:px-6">
        <div className="mx-auto max-w-2xl">
          <header className="border-b border-hairline pb-6">
            <p className="text-sm text-ink-muted">Bravo Manufacturing</p>
            <h1 className="mt-1">
              {session.contact_name ? `Ciao ${session.contact_name},` : "Ciao,"}
            </h1>
            <p className="mt-2">
              ecco il riepilogo di quanto visto insieme per <strong>{company}</strong>.
            </p>
          </header>

          <section className="mt-8">
            <h2 className="text-base font-semibold text-ink-display">
              Temi affrontati
            </h2>
            {topics.length > 0 ? (
              <ul className="mt-3 flex flex-wrap gap-2">
                {topics.map((label, i) => (
                  <li key={i}>
                    <Badge tone="accent">{label}</Badge>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="mt-2 text-ink-muted">Nessun tema registrato.</p>
            )}
          </section>

          {questions.length > 0 && (
            <section className="mt-8">
              <h2 className="text-base font-semibold text-ink-display">
                Punti emersi
              </h2>
              <ul className="mt-3 list-disc space-y-1 pl-5">
                {questions.map((q, i) => (
                  <li key={i}>{q}</li>
                ))}
              </ul>
            </section>
          )}

          <section className="mt-8">
            <h2 className="text-base font-semibold text-ink-display">
              Approfondimenti video
            </h2>
            {discussedVideos.length > 0 ? (
              <div className="mt-3 flex flex-col gap-6">
                {discussedVideos.map((c) => (
                  <VideoCard key={c.id} criticality={c} />
                ))}
              </div>
            ) : (
              <p className="mt-2 text-ink-muted">
                Nessun video di approfondimento disponibile.
              </p>
            )}
          </section>

          {otherVideos.length > 0 && (
            <section className="mt-8">
              <h2 className="text-base font-semibold text-ink-display">
                Altri approfondimenti
              </h2>
              <p className="mt-1 text-sm text-ink-muted">
                Temi vicini al tuo contesto che potrebbero interessarti.
              </p>
              <div className="mt-3 flex flex-col gap-6">
                {otherVideos.map((c) => (
                  <VideoCard key={c.id} criticality={c} />
                ))}
              </div>
            </section>
          )}

          {appointment && (
            <section className="mt-8">
              <h2 className="text-base font-semibold text-ink-display">
                Appuntamento col commerciale
              </h2>
              <div className="mt-3 rounded-md border border-hairline bg-surface px-4 py-4">
                <p className="text-sm">
                  <strong>{appointment.display}</strong>
                </p>
                {appointment.sales_name && (
                  <p className="mt-1 text-sm text-ink-muted">
                    Commerciale: {appointment.sales_name}
                  </p>
                )}
                {appointment.location && (
                  <p className="mt-1 text-sm text-ink-muted">
                    Luogo: {appointment.location}
                  </p>
                )}
                <div className="mt-4 flex flex-wrap gap-2">
                  <Button asChild variant="secondary" size="sm">
                    <a href={appointment.ics_url}>
                      <CalendarPlus className="h-4 w-4" />
                      Aggiungi al calendario
                    </a>
                  </Button>
                  <Button asChild variant="secondary" size="sm">
                    <a
                      href={appointment.google_url}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      <CalendarPlus className="h-4 w-4" />
                      Google Calendar
                    </a>
                  </Button>
                </div>
              </div>
            </section>
          )}

          <footer className="mt-12 border-t border-hairline pt-6 text-sm text-ink-muted">
            A presto, il team Bravo Manufacturing.
          </footer>
        </div>
      </div>
    </>
  )
}

function VideoCard({ criticality }: { criticality: RecapCriticality }) {
  return (
    <div>
      <h3 className="mb-2 text-sm font-medium text-ink-display">
        {criticality.label}
      </h3>
      {criticality.embed_url ? (
        <div className="aspect-video w-full overflow-hidden rounded-md border border-hairline bg-surface">
          <iframe
            src={criticality.embed_url}
            title={criticality.label}
            loading="lazy"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowFullScreen
            className="h-full w-full"
          />
        </div>
      ) : (
        <a
          href={criticality.video_url as string}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center justify-between gap-3 rounded-md border border-hairline px-4 py-3 no-underline hover:bg-surface"
        >
          <span className="text-sm text-ink-body">Guarda il video</span>
          <ExternalLink className="h-4 w-4 shrink-0 text-ink-muted" />
        </a>
      )}
    </div>
  )
}
