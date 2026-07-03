# Milestone 16 — Questionario esteso: condizionali e rifiniture

Stai entrando in plan mode per pianificare e poi costruire il milestone 16 di questo progetto (Fase 5). Dipende da M15 (framework del questionario: `qualification_answers`, `questionnaire.json`, rendering a gruppi in `Profiling.tsx`, primitive di campo).

## Contesto

- Leggi `@docs/roadmap/fase-5-questionario-esteso/prd.md` per scope, modello dati e l'**Appendice A** (le condizioni `visible_if` per campo sono annotate lì).
- Leggi il log di M15 — `@docs/roadmap/fase-5-questionario-esteso/milestones/15-questionario-framework/milestone-log.md` — per la forma di `questionnaire.json`, come sono resi i campi e dove vive lo stato delle risposte.
- Riusa lo stato delle risposte e la resa dei campi introdotti in M15; qui si aggiunge logica di visibilità/derivazione/validazione, senza ridisegnare il framework.

## Il tuo compito

1. Pianifica l'implementazione **solo** del milestone 16 come definito nel PRD:
   - **Visibilità condizionale (`visible_if`)**: mostra i campi di dettaglio solo quando la condizione è vera — `contact_role_other` (se `contact_roles` contiene "Altro"), `subcontract_turnover_percentage` (se `does_subcontract_manufacturing` = sì), `production_management_software_name` (se `has_production_management_software` = sì), e i vari `*_other_text` (se la relativa scelta multipla contiene "Altro"). Un valore già inserito in un campo poi nascosto va gestito coerentemente (definisci il comportamento nel piano).
   - **Auto-somma `total_people_count`**: somma dei quattro conteggi, ma **correggibile a mano** (un override manuale non viene sovrascritto dai cambi successivi finché non viene azzerato).
   - **Validazioni leggere**: interi ≥ 0, percentuali 0–100, valuta ≥ 0; feedback inline non bloccante, coerente col design system.
   - **NON** aggiungere sync HubSpot né esposizione delle risposte a valle: fuori scope Fase 5.
2. Dopo che l'utente ha confermato il piano, costruisci solo ciò che rientra nello scope del milestone 16.
3. Verifica il lavoro rispetto ai criteri "Done when" del milestone 16 nel PRD: aggiungi/aggiorna i test (visibilità condizionale, auto-somma, validazioni), verifica con screenshot, e assicurati che `bin/rails test` passi al 100% e `npm run check` sia pulito.
4. Al completamento, scrivi un `milestone-log.md` in questa cartella (`docs/roadmap/fase-5-questionario-esteso/milestones/16-questionario-condizionali/milestone-log.md`), con `## Novità nell'app` in cima (bullet orientati all'utente) e poi le sezioni di dettaglio implementativo (cosa è stato costruito, decisioni non pre-specificate, cosa serve dopo, scostamenti dal PRD).

Fammi qualsiasi domanda di chiarimento usando lo strumento AskUserQuestion per definire il piano di implementazione di questo milestone.
