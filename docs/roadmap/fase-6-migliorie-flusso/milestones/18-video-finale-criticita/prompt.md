# Milestone 18 — Video finale per criticità

Stai entrando in plan mode per pianificare e poi costruire il milestone 18 di questo progetto (Fase 6). Aggiunge, in coda al flusso live di ogni criticità, una slide con il video di approfondimento già configurato in `content/config/videos.json` e già usato nel recap pubblico.

## Contesto

- Leggi `@docs/roadmap/fase-6-migliorie-flusso/prd.md` per il contesto della Fase 6, in particolare la sezione "Milestone M18".
- Leggi `docs/roadmap/fase-6-migliorie-flusso/milestones/17-flusso-e-questionario-due-fasi/milestone-log.md` per capire cosa è stato costruito nel milestone precedente (questo milestone è indipendente da quello, ma condivide la stessa release).
- Riusa integralmente:
  - `ContentConfig.video_url_for` (in `app/models/content_config.rb`) — risoluzione dell'URL video per criticità con override segmento/token, identica a quella già usata nel recap.
  - `app/lib/video_embed.rb` (`VideoEmbed.url`) — conversione dell'URL grezzo in un embed YouTube-nocookie/Vimeo, o `nil` se non riconosciuto.
  - `app/controllers/public_recaps_controller.rb` come riferimento di come le due cose si combinano oggi.
  - `app/frontend/components/present/SlidePlayer.tsx` — il pattern step (`title`/`body`/`phases`), il componente `SlideImage` con il suo stato di placeholder su immagine mancante (da imitare per il placeholder "Video non disponibile").
  - `app/frontend/components/present/Stage.tsx` — il frame 16:9 condiviso.
  - `PresaleSessionsController#steps_by_criticality` (o l'equivalente dopo il milestone 17) — punto in cui aggiungere lo step video sintetico in coda a ogni criticità.

## Il tuo compito

1. Pianifica l'implementazione **solo** del milestone 18 come definito nel PRD:
   - aggiungi uno step finale per ogni criticità nel flusso live, risolto con `ContentConfig.video_url_for` + `VideoEmbed.url` nello stesso contesto segmento/token già usato altrove nella sessione;
   - layout fullscreen nello `Stage` 16:9: solo player + logo Bravo, niente titolo/corpo testo;
   - riproduzione click-to-play (nessun autoplay): il player mostra la thumbnail, il click sul player stesso avvia il video; il click sul resto dello stage / il tasto → restano il modo per avanzare (come su ogni altra slide);
   - se l'URL non risolve a un embed valido, mostra comunque lo step ma con un placeholder "Video non disponibile" (stesso trattamento visivo di `SlideImage` per le immagini mancanti) — capiterà per ogni criticità finché `videos.json` contiene solo placeholder testuali, è il comportamento atteso.
2. Dopo che l'utente ha confermato il piano, costruisci solo ciò che rientra nello scope del milestone 18. **Non** aggiungere autoplay, controlli avanzati del player, analytics di visione, né una nuova infrastruttura di config per i video (`videos.json` resta identico nella forma).
3. Verifica il lavoro rispetto ai criteri "Done when" del milestone 18 nel PRD: percorri manualmente una criticità fino in fondo e osserva la slide video finale (sia nel caso placeholder sia, se possibile, con un URL YouTube/Vimeo reale di prova); aggiorna/aggiungi test (risoluzione dell'URL nel contesto segmento/token, rendering placeholder vs player); verifica con screenshot desktop + mobile; assicurati che `bin/rails test` passi al 100%.
4. Al completamento, scrivi un `milestone-log.md` in questa cartella (`docs/roadmap/fase-6-migliorie-flusso/milestones/18-video-finale-criticita/milestone-log.md`), con `## Novità nell'app` in cima (bullet orientati all'utente) e poi le sezioni di dettaglio implementativo.

Fammi qualsiasi domanda di chiarimento usando lo strumento AskUserQuestion per definire il piano di implementazione di questo milestone.
