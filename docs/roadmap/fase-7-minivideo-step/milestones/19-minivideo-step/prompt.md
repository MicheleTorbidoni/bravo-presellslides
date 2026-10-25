# Milestone 19 — Minivideo come step o fase di step

Stai entrando in plan mode per pianificare e poi costruire il milestone 19 di questo progetto (Fase 7). Permette che uno step, o una fase di uno step, del flusso live sia un minivideo `.mp4` invece di una bitmap PNG, con lo stesso modello file-driven già usato per le immagini.

## Contesto

- Leggi `@docs/roadmap/fase-7-minivideo-step/prd.md`, in particolare la grammatica dei nomi file e la sezione "Milestone M19".
- Leggi `docs/roadmap/fase-6-migliorie-flusso/milestones/18-video-finale-criticita/milestone-log.md`: lo step video finale di M18 è una cosa diversa (embed YouTube da `videos.json`) e resta invariato. Contiene anche la lezione sull'autoplay non muto.
- Leggi `docs/asset-pipeline-spec.md` per il modello asset attuale (catena di risoluzione, struttura segment-driven, fasi `.f<Z>`).
- Riusa ed estendi:
  - `app/models/content_config.rb`: `parse_asset_name`, `structure_in_dir`, `step_structure`, `resolve_phase_url`, `intro_steps`, `asset_exists?`, `asset_url`.
  - `app/controllers/presentation_assets_controller.rb`: content type, Range, cache.
  - `app/frontend/components/present/SlidePlayer.tsx`: tipo `Step`, `SlideImage`, `MissingPlaceholder`, pattern `stopPropagation` della facade M18.
  - `app/javascript/pages/Present.tsx`: navigazione basata su `.phases.length`, da non rompere.
- Stato attuale dei contenuti: tutte le cartelle dei segmenti sono vuote, tutto arriva da `content/assets/criticalities/`. Lì ci sono già 11 `.mp4` segnaposto (identici, 241 KB) e un `.mov` reale (`C04-step3.mov`, 19 MB). `ffmpeg` non è installato sulla macchina.

## Il tuo compito

1. Pianifica l'implementazione **solo** del milestone 19 come definito nel PRD. In particolare decidi e motiva:
   - la nuova forma delle fasi verso il frontend (oggetto `{ url, kind, audio }` oppure altro) e l'impatto su intro, criticità, tipi e test esistenti;
   - come ottenere il supporto HTTP Range per `send_file` in questo stack, verificandolo invece di darlo per scontato;
   - come costruire il parametro di versione `?v=` senza rallentare la risoluzione (le chiamate `File.file?` sono già molte).
2. Dopo che l'utente ha confermato il piano, costruisci solo ciò che rientra nello scope del milestone 19. Lavora su un feature branch: il flusso è feature branch → staging → main.
3. Converti `C04-step3.mov` in `C04-step3.mp4` con lo script nuovo (se `ffmpeg` manca, chiedi all'utente di installarlo con `! brew install ffmpeg`). Non committare mai i `.mov`.
4. Verifica rispetto ai criteri "Done when" del PRD: percorri nel browser una criticità con step video, una con fase video e un caso `.audio`; controlla gli header di risposta (content type, `206` su Range, cache). Aggiungi i test, fai gli screenshot desktop + mobile in `tmp/screenshots/` e assicurati che `bin/rails test` e `bin/rails test:system` passino al 100%.
5. Aggiorna `docs/asset-pipeline-spec.md` con la grammatica estesa.
6. Al completamento, scrivi `docs/roadmap/fase-7-minivideo-step/milestones/19-minivideo-step/milestone-log.md`, con `## Novità nell'app` in cima (bullet orientati all'utente) e poi le sezioni di dettaglio implementativo.

Fammi qualsiasi domanda di chiarimento usando lo strumento AskUserQuestion per definire il piano di implementazione di questo milestone.
