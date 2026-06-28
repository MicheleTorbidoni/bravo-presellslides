# Milestone 13 — Simulatore + evidenza nell'hub

Stai entrando in plan mode per pianificare e poi costruire il milestone 13 di questo progetto (Fase 3). Dipende da M11 (endpoint inbound) e M12 (endpoint selezione + subset per-segmento + criticità suggerite).

## Contesto

- Leggi `@docs/roadmap/fase-3-hubspot-simulazione/prd.md` per il contesto della Fase 3: scope, modello dati, contratto di integrazione.
- Leggi i log di M11 e M12 — `@docs/roadmap/fase-3-hubspot-simulazione/milestones/11-*/milestone-log.md` e `@docs/roadmap/fase-3-hubspot-simulazione/milestones/12-*/milestone-log.md` — per i due endpoint, lo schema di firma e i campi disponibili.
- Riusa: l'area `admin` esistente (rotte e pattern di pagina Inertia); `Hub.tsx` e `Present.tsx` (pillole criticità e stati visivi da-fare/completata, token `bm-*`); l'azione admin chiamata via router Inertia deve **redirezionare** (non `head`), come da regole Inertia in `CLAUDE.md`.
- Il simulatore deve firmare e fare un POST reale ai due endpoint (round-trip autentico), non scrivere a DB direttamente; la selezione criticità è **casuale** dal subset del segmento.

## Il tuo compito

1. Pianifica l'implementazione **solo** del milestone 13 come definito nel PRD: generatore di dati placeholder (senza nuove gemme), pagina admin "Simula prenotazione da HubSpot" che mette in scena prenotazione + selezione casuale, prop delle criticità suggerite verso l'hub e contrassegno sulle pillole suggerite (compatibile con lo stato completato).
2. Dopo che l'utente ha confermato il piano, costruisci solo ciò che rientra nello scope del milestone 13.
3. Verifica il tuo lavoro rispetto ai criteri "Done when" del milestone 13 nel PRD. Esegui `bin/rails test`, `npm run check`, `bin/rubocop`; verifica il flusso end-to-end nel browser con la skill `agent-browser` e salva screenshot desktop/mobile in `tmp/screenshots/`.
4. Al completamento, scrivi un `milestone-log.md` in questa cartella (`docs/roadmap/fase-3-hubspot-simulazione/milestones/13-simulatore-badge-hub/milestone-log.md`), con `## Novità nell'app` in cima (bullet orientati all'utente) e poi le sezioni di dettaglio implementativo (cosa è stato costruito, decisioni non pre-specificate, scostamenti dal PRD).

Fammi qualsiasi domanda di chiarimento usando lo strumento AskUserQuestion per definire il piano di implementazione di questo milestone.
