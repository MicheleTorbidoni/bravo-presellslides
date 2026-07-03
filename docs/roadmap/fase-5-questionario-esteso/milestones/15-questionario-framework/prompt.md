# Milestone 15 — Questionario esteso: framework

Stai entrando in plan mode per pianificare e poi costruire il milestone 15 di questo progetto (Fase 5). Estende la schermata di **Profilazione** (`app/javascript/pages/PresaleSessions/Profiling.tsx`), che dalla PR #35 mostra già tutte le domande dell'albero decisionale insieme con disabilitazione a cascata e ricostruzione deterministica di `operational_profile`.

## Contesto

- Leggi `@docs/roadmap/fase-5-questionario-esteso/prd.md` per il contesto della Fase 5: scope, modello dati, staging e — importante — l'**Appendice A**, che è la fonte di verità in-repo del contenuto del questionario (gruppi, campi, tipi, opzioni, condizioni). Popola `content/config/questionnaire.json` da lì.
- Riusa:
  - `Profiling.tsx` — walk generico che calcola le domande abilitate, ricostruzione di `operational_profile`, gate "Avanti". **Non cambiare la logica dei token.**
  - `ContentConfig` (`decision_tree`, `load_config`) per leggere il nuovo `questionnaire.json`; le domande-criticità restano risolte da `decision-tree.json`.
  - Il pattern **auto-save debounced** già usato in `Setup.tsx` + `PresaleSessionsController#update` (via `apiPatch`) come riferimento per salvare e ripristinare le risposte.
  - Le colonne jsonb esistenti (`captured_questions`, `extra_criticalities`) come precedente per la nuova colonna.
  - Design system: `Checkbox`, `Radio`/`RadioGroup`, `Input`, `Badge`, token (`bg-accent/5`, `border-hairline`, ecc.). Ricorda le regole di CLAUDE.md su elementi semantici e primitive.

## Il tuo compito

1. Pianifica l'implementazione **solo** del milestone 15 come definito nel PRD:
   - migrazione: colonna `qualification_answers` (jsonb) su `PresaleSession`;
   - `content/config/questionnaire.json` con gruppi + elementi (`ref` alle domande-criticità e campi extra inline) dall'Appendice A;
   - rendering unificato a gruppi in `Profiling.tsx`: i `ref` risolvono le domande dell'albero (con la disabilitazione a cascata esistente), i campi inline rendono il tipo appropriato;
   - primitive di campo (scelta multipla, testo, intero, valuta, percentuale, sì/no) + nuovo primitivo **`Textarea`** nel design system (`components/ui/textarea.tsx` + sezione su `/admin/design-system`);
   - distinzione visiva: card domande-criticità con **sfondo accent tenue**, extra neutre;
   - **toggle "Mostra solo domande per le criticità"** in testa (filtra ai soli `ref`);
   - auto-save di `qualification_answers` + ripristino al reload; gate "Avanti" invariato (solo domande-criticità sul percorso attivo).
   - **NON** implementare `visible_if` (i campi condizionali restano sempre visibili), l'auto-somma del totale, le validazioni: sono M16.
2. Dopo che l'utente ha confermato il piano, costruisci solo ciò che rientra nello scope del milestone 15.
3. Verifica il lavoro rispetto ai criteri "Done when" del milestone 15 nel PRD: aggiungi/aggiorna i test (config/controller + system test della UX), verifica con screenshot desktop + mobile, e assicurati che `bin/rails test` passi al 100% e `npm run check` sia pulito.
4. Al completamento, scrivi un `milestone-log.md` in questa cartella (`docs/roadmap/fase-5-questionario-esteso/milestones/15-questionario-framework/milestone-log.md`), con `## Novità nell'app` in cima (bullet orientati all'utente) e poi le sezioni di dettaglio implementativo (cosa è stato costruito, decisioni non pre-specificate, cosa serve al milestone successivo, scostamenti dal PRD).

Fammi qualsiasi domanda di chiarimento usando lo strumento AskUserQuestion per definire il piano di implementazione di questo milestone.
