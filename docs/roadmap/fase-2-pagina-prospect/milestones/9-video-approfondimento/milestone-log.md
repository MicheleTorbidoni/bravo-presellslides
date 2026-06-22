# Milestone 9 — Video di approfondimento nella pagina

## Novità nell'app

- Sulla pagina del prospect i video di approfondimento ora si **guardano direttamente in pagina** (player embeddato), senza aprire link esterni.
- Le **criticità discusse in call** appaiono in evidenza con il loro video; le **altre criticità del contesto** del prospect compaiono sotto, in "Altri approfondimenti".
- Ogni video è quello **più pertinente al caso del prospect** (segmento × profilo), grazie alla risoluzione già esistente.
- I player sono **responsive** (16:9) e si caricano in modo leggero (lazy-loading).

## Cosa è stato costruito

### Backend

- **`app/lib/video_embed.rb`** (nuovo PORO) — `VideoEmbed.url(raw)` converte un link video in URL embeddabile: YouTube (`watch?v=`, `youtu.be/`, `/embed/`) → `https://www.youtube-nocookie.com/embed/<id>` (privacy-enhanced); Vimeo (`vimeo.com/<id>`) → `https://player.vimeo.com/video/<id>`; URL non riconosciuto/blank → `nil`.
- **`app/controllers/public_recaps_controller.rb`** — in `recap_criticalities`, ogni elemento del subset porta ora anche `embed_url: VideoEmbed.url(video_url)` accanto a `video_url`. Nessun'altra modifica (la risoluzione per contesto resta `ContentConfig.video_url_for`).

### Frontend

- **`app/javascript/pages/PublicRecap.tsx`** — la sezione "Approfondimenti video" non è più una lista di link ma **player inline**:
  - tipo `RecapCriticality` esteso con `embed_url`;
  - `discussedVideos` (discusse con video) renderizzate in evidenza in "Approfondimenti video"; `otherVideos` (resto del subset con video) in una sezione "Altri approfondimenti";
  - nuovo componente locale `VideoCard`: se `embed_url` presente → `<iframe>` 16:9 (`aspect-video`, `loading="lazy"`, `allowFullScreen`) con etichetta criticità; altrimenti fallback a link esterno;
  - messaggio "Nessun video di approfondimento disponibile" se non ci sono discusse con video.

### Test

- `VideoEmbed`: conversioni YouTube watch/youtu.be/embed → nocookie embed; Vimeo → player; non riconosciuto/blank → nil.
- `PublicRecapsController#show`: ogni criticità porta `embed_url` coerente con `video_url` (variante risolta per segmento+token).

## Decisioni prese (non pre-specificate nel PRD)

- **Tutti i player inline** (scelta UX confermata dall'utente): discusse prima, poi le correlate; niente click-to-load. Mitigato con `loading="lazy"`.
- **Embed YouTube via `youtube-nocookie.com`** per privacy (nessun cookie finché il prospect non avvia il video).
- **Conversione embed lato backend** (`embed_url` nelle props), così la pagina resta "dumb" e la logica è testabile in Ruby.
- **`content/config/videos.json` invariato**: la struttura supporta già le varianti per segmento/token e i contenuti sono placeholder — l'autoraggio dei video reali è lavoro di contenuto, non di codice.

## Scostamenti dal PRD

Nessuno. Tutti i criteri "Fatto quando" di M9 sono coperti.

## Chiusura Fase 2

Con M9 la **Fase 2 (pagina prospect)** è completa: M8 (pagina pubblica tokenizzata + link nel recap), M10 (appuntamento col commerciale) e M9 (video embeddati e contestualizzati) sono tutti rilasciati. La pagina pubblica del prospect ora raccoglie riepilogo, punti emersi, video di approfondimento riproducibili e l'eventuale appuntamento col commerciale con aggiunta al calendario.

*Nota di verifica:* `bin/rails test` (101 runs, 0 failures), `npm run check`, rubocop e un render SSR della pagina (iframe corretti, discusse prima delle correlate, fallback link) passano. La verifica UI interattiva con la skill `agent-browser` non è disponibile in questa sessione e va ripresa manualmente (resa effettiva dei player con video reali, responsività mobile).
