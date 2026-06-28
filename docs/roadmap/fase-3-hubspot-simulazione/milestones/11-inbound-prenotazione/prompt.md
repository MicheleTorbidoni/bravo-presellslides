# Milestone 11 — Inbound: sessione da prenotazione

Stai entrando in plan mode per pianificare e poi costruire il milestone 11 di questo progetto (Fase 3). È il primo della Fase 3 e fa da base ai successivi.

## Contesto

- Leggi `@docs/roadmap/fase-3-hubspot-simulazione/prd.md` per il contesto della Fase 3: scope, modello dati, fondamenta esistenti, contratto di integrazione.
- Leggi i log dei milestone precedenti utili a inquadrare il modello: M10 (appuntamento) e M8 (token pubblico) — `@docs/roadmap/fase-2-pagina-prospect/milestones/10-*/milestone-log.md` e `@docs/roadmap/fase-2-pagina-prospect/milestones/8-*/milestone-log.md`.
- Riusa: il modello `PresaleSession` e i suoi campi appuntamento esistenti; il modello `User` per individuare l'operatore; il pattern dei controller non-Inertia (chiamati da servizi esterni via raw JSON, dove `head`/`render json` sono leciti — vedi l'eccezione in `CLAUDE.md`).
- Contratto inbound (flat JSON da HubSpot Workflow "Send a webhook") e firma `X-HubSpot-Signature-v3`: dettagli nel PRD, sezione "Contratto di integrazione".

## Il tuo compito

1. Pianifica l'implementazione **solo** del milestone 11 come definito nel PRD (endpoint inbound + verifica firma, i 4 campi nuovi su `PresaleSession`, creazione sessione pre-valorizzata con owner assegnato, doc del contratto inbound). Non costruire selezione criticità, subset, badge o simulatore: sono M12/M13.
2. Dopo che l'utente ha confermato il piano, costruisci solo ciò che rientra nello scope del milestone 11.
3. Verifica il tuo lavoro rispetto ai criteri "Done when" del milestone 11 nel PRD (POST firmato → sessione pre-valorizzata nell'elenco; firma errata → rifiutata). Aggiungi test d'integrazione.
4. Al completamento, scrivi un `milestone-log.md` in questa cartella (`docs/roadmap/fase-3-hubspot-simulazione/milestones/11-inbound-prenotazione/milestone-log.md`), con `## Novità nell'app` in cima (bullet orientati all'utente) e poi le sezioni di dettaglio implementativo (cosa è stato costruito, decisioni non pre-specificate, cosa serve al milestone successivo, scostamenti dal PRD).

Fammi qualsiasi domanda di chiarimento usando lo strumento AskUserQuestion per definire il piano di implementazione di questo milestone.
