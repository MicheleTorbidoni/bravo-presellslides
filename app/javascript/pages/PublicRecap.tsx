import { Head } from "@inertiajs/react"
import { ExternalLink } from "lucide-react"
import { Badge } from "@/components/ui/badge"

type RecapCriticality = {
  id: number
  label: string
  discussed: boolean
  video_url: string | null
}

export default function PublicRecap({
  session,
  topics,
  questions,
  criticalities,
}: {
  session: { company_name: string | null; contact_name: string | null }
  topics: string[]
  questions: string[]
  criticalities: RecapCriticality[]
}) {
  const company = session.company_name || "la vostra azienda"
  // M8: i video sono link semplici per le criticità effettivamente discusse che
  // hanno un URL risolto. Embedding + esplorazione del resto del subset → M9.
  const videoItems = criticalities.filter((c) => c.discussed && c.video_url)

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
            {videoItems.length > 0 ? (
              <ul className="mt-3 divide-y divide-hairline overflow-hidden rounded-md border border-hairline">
                {videoItems.map((c) => (
                  <li key={c.id}>
                    <a
                      href={c.video_url as string}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center justify-between gap-3 px-4 py-3 no-underline hover:bg-surface"
                    >
                      <span className="text-sm font-medium text-ink-display">
                        {c.label}
                      </span>
                      <ExternalLink className="h-4 w-4 shrink-0 text-ink-muted" />
                    </a>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="mt-2 text-ink-muted">
                Nessun video di approfondimento disponibile.
              </p>
            )}
          </section>

          <footer className="mt-12 border-t border-hairline pt-6 text-sm text-ink-muted">
            A presto, il team Bravo Manufacturing.
          </footer>
        </div>
      </div>
    </>
  )
}
