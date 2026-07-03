# Milestone M14 — Criticità extra da altri segmenti

Entri in plan mode per pianificare e poi costruire il milestone M14 di questo progetto.

## Contesto

- Leggi `@docs/roadmap/fase-4-criticita-cross-segmento/prd.md` per scope, novità, modello dati e vincoli della Fase 4.
- Leggi `@CLAUDE.md` (regole Inertia, design system, testing) e i PRD delle fasi precedenti se serve contesto sulle superfici già costruite (`docs/roadmap/fase-2-*`, `docs/roadmap/fase-3-*`).

## Indicazioni tecniche già decise

Il crux è che `effective_selected_ids` e `effective_criticalities_order` in `app/controllers/presale_sessions_controller.rb` fanno `& segment_ids`, scartando gli id fuori dal segmento del prospect. Piano concordato:

**Modello dati**
- Migration: nuova colonna `extra_criticalities` (jsonb, default `[]`) su `presale_sessions`, array di `{ id, segment }`.

**Backend (`PresaleSessionsController`, `ContentConfig`, `PublicRecapsController`)**
- `session_params`: permettere `extra_criticalities: [[:id, :segment]]`.
- Helper privati: mappa `id => segment` degli extra e `allowed_ids(session) = segment_ids ∪ extra_ids`.
- `effective_selected_ids` / `effective_criticalities_order`: usare `allowed_ids` al posto di `& segment_ids` (gli extra nascono selezionati perché l'"Aggiungi" li mette in `selected_criticalities`).
- `setup`: aggiungere la prop `extraCriticalities` (id + segment).
- `steps_by_criticality`: risolvere ogni criticità contro il **suo** segmento — per gli id extra il segmento di origine, altrimenti `session.segment`.
- `PublicRecapsController#recap_criticalities`: includere gli extra discussi (append + dedup) con `video_url_for` risolto sul segmento di origine.
- `present`/`result`/`debrief` non cambiano: derivano già da `effective_*`.

**Frontend (`app/javascript/pages/PresaleSessions/Setup.tsx`)**
- Prop/stato `extras`; aggiungere `extra_criticalities` ai payload `apiPatch` (debounced + `continueToProfiling`) e alle dipendenze dell'effetto.
- Lista combinata: includere gli extra (cercati in `criticalitiesBySegment[extra.segment]`) come righe `SortableCriticality` con badge del segmento di origine e "X" di rimozione (estendere il componente con props opzionali `sourceSegmentLabel?` / `onRemove?` così le righe di segmento restano invariate).
- Pannello "Aggiungi da un altro segmento": `<Select>` con i segmenti meno quello del prospect; elenco criticità del segmento scelto con "Aggiungi" abilitato solo per gli id non nel subset corrente e non già in `extras`.
- `pickSegment`: azzerare anche gli extra.

## Il tuo compito

1. Pianifica l'implementazione **solo** del milestone M14 come definito nel PRD. Non pianificare né costruire altro.
2. Dopo la conferma del piano, costruisci solo ciò che è nello scope di M14.
3. Verifica contro i criteri "Done when" del PRD: aggiungi/aggiorna i test (`bin/rails test`) per gli extra in `effective_*`, `setup`, `present`/`steps_by_criticality` e `recap_criticalities`; verifica la UI end-to-end con la skill `agent-browser` e uno screenshot in `tmp/screenshots/`; esegui `npm run check` e `bin/rubocop`.
4. A fine milestone scrivi un `milestone-log.md` in questa cartella:
   - inizia con `## Novità nell'app` (elenco puntato, leggibile da non tecnici, delle nuove capacità visibili);
   - poi le sezioni di dettaglio (cosa è stato costruito, decisioni prese non pre-specificate, cosa deve sapere il prossimo milestone, eventuali deviazioni dal PRD e perché).

Fai domande di chiarimento con AskUserQuestion per bloccare il piano di M14.
