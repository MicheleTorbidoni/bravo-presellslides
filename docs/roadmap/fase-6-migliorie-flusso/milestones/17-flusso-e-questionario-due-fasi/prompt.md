# Milestone 17 — Riordino del flusso e questionario in due fasi

Stai entrando in plan mode per pianificare e poi costruire il milestone 17 di questo progetto (Fase 6). Sposta il Questionario A (`/profiling`) prima del Setup, introduce una nuova schermata "Questionario B" dopo la presentazione, e riorganizza `content/config/questionnaire.json`.

## Contesto

- Leggi `@docs/roadmap/fase-6-migliorie-flusso/prd.md` per il contesto della Fase 6: scope, modello dati e — importante — l'**Appendice B**, che è la fonte di verità in-repo della struttura finale di `questionnaire.json` (quali gruppi restano in fase 1, quale nuovo gruppo va creato, cosa si sposta in fase 2, cosa va rimosso).
- Riusa:
  - `Profiling.tsx` — rendering a gruppi, gate "Avanti" (`walkProfile`/`enabledIds`), auto-save via `apiPatch`. **Non cambiare la logica dei token/dell'albero decisionale.**
  - `ContentConfig` per leggere `questionnaire.json` (nessuna modifica al parser dovrebbe servire, solo al contenuto del file e a quali gruppi ogni schermata mostra).
  - `content/config/mappings.json` — già 126 righe segmento×profilo; serve un nuovo metodo di lookup sulla singola riga segmento+profilo (oggi `ContentConfig.criticalities_for_segment` fa l'unione su tutti i profili di un segmento, va aggiunto un lookup più specifico).
  - `Setup.tsx` e `PresaleSessionsController#effective_selected_ids`/`allowed_ids` — punto di estensione per il nuovo criterio di default (unione HubSpot + mapping segmento+profilo, clampato al segmento).
  - `Closing.tsx` (`app/frontend/components/present/Closing.tsx`) — bottoni esistenti "Vai al riepilogo"/"Torna all'hub".
  - Design system e pattern auto-save esistenti per l'eventuale nuova schermata Questionario B (probabilmente una variante leggera di `Profiling.tsx` o un componente condiviso che filtra i gruppi da mostrare).

## Il tuo compito

1. Pianifica l'implementazione **solo** del milestone 17 come definito nel PRD:
   - riorganizza `content/config/questionnaire.json` secondo l'Appendice B (nuovo gruppo "Terziarizzazione", gruppo "Azienda" ridotto a fase 2, rimozione di Motivazione/Obiettivi/Aspettative);
   - `PresaleSessionsController#create` reindirizza a `/profiling` invece che a `/setup`;
   - in `Profiling.tsx`: "Avanti" porta a `/setup` (invariato il gate), rimuovi il bottone "Indietro" verso Setup;
   - in `Setup.tsx`: "Avanti" porta a `/present` invece che a `/profiling`; nessun bottone verso Questionario A;
   - estendi il default delle criticità suggerite in Setup: unione tra `suggested_criticalities` (HubSpot) ∩ segmento, come oggi, e il nuovo lookup segmento+profilo su `mappings.json`, sempre clampato al segmento;
   - nuova route/azione per "Questionario B" (nome a tua scelta, es. `qualification`), che mostra solo il gruppo Azienda ridotto (fase 2), senza gate; un solo bottone finale verso `/result`, nessun "Indietro";
   - in `Closing.tsx`: il bottone "Vai al riepilogo" diventa "Completa scheda" e porta alla nuova schermata Questionario B; "Torna all'hub" invariato.
2. Dopo che l'utente ha confermato il piano, costruisci solo ciò che rientra nello scope del milestone 17. **Non** toccare la logica dei token/dell'albero decisionale, e **non** differenziare il contenuto di `mappings.json` (resta con lo stesso set di criticità per ogni profilo di un segmento — fuori scope, vedi PRD).
3. Verifica il lavoro rispetto ai criteri "Done when" del milestone 17 nel PRD: percorri manualmente A→Setup→Present→Chiusura→B→Result; aggiorna/aggiungi test (controller per i nuovi redirect e la nuova route, config per la struttura di `questionnaire.json`, system test end-to-end della UX); verifica con screenshot desktop + mobile delle schermate toccate; assicurati che `bin/rails test` passi al 100% e `npm run check` sia pulito.
4. Al completamento, scrivi un `milestone-log.md` in questa cartella (`docs/roadmap/fase-6-migliorie-flusso/milestones/17-flusso-e-questionario-due-fasi/milestone-log.md`), con `## Novità nell'app` in cima (bullet orientati all'utente) e poi le sezioni di dettaglio implementativo (cosa è stato costruito, decisioni non pre-specificate, cosa serve al milestone successivo — in particolare il nome esatto della route Questionario B e come sono strutturati i suoi props, utile a M18 —, scostamenti dal PRD).

Fammi qualsiasi domanda di chiarimento usando lo strumento AskUserQuestion per definire il piano di implementazione di questo milestone.
