# Milestone 8 — Pagina prospect pubblica & link nel recap

Stai entrando in plan mode per pianificare e poi costruire il milestone 8 di questo progetto (primo milestone della Fase 2).

## Contesto

- Leggi `@docs/roadmap/fase-2-pagina-prospect/prd.md` per il contesto completo della Fase 2: scope, modello dati, fondamenta esistenti da riusare.
- Questa Fase 2 è costruita **sopra** i 7 milestone iniziali già rilasciati. Leggi i loro `milestone-log.md` (`@_build_plan/milestones/1-*/milestone-log.md` … `@_build_plan/milestones/7-*/milestone-log.md`) per capire cosa è già stato costruito — in particolare M6 (debrief + recap email) e M7 (archivio), che questo milestone estende.
- Riusa le fondamenta esistenti indicate nel PRD: `allow_unauthenticated_access` per la pagina pubblica, `PresaleRecapMailer` e la logica recap di M6, i dati del debrief, la pipeline Inertia/SSR e i file di discovery (sitemap/robots/llms).

## Il tuo compito

1. Pianifica l'implementazione **solo** del milestone 8 come definito nel PRD. Non pianificare né costruire nulla del milestone 9.
2. Dopo che l'utente ha confermato il piano, costruisci solo ciò che rientra nello scope del milestone 8.
3. Verifica il tuo lavoro rispetto ai criteri "Fatto quando" del milestone 8 nel PRD.
4. Al completamento, scrivi un `milestone-log.md` in questa cartella (`docs/roadmap/fase-2-pagina-prospect/milestones/8-pagina-prospect-pubblica/milestone-log.md`). Strutturalo così:
   - **Inizia con una sezione `## Novità nell'app` proprio in cima.** Un elenco puntato conciso e leggibile delle principali funzionalità rivolte all'utente aggiunte in questo milestone, scritto in modo che un revisore non tecnico possa vedere a colpo d'occhio le novità. Inquadra ogni punto come una capacità che l'utente vedrà o potrà fare, non come un artefatto tecnico. Tienilo breve e scansionabile.
   - Poi includi le sezioni di dettaglio implementativo per il milestone successivo:
     - Cosa è stato costruito (file creati, modelli/campi aggiunti, route aggiunte, ecc.)
     - Eventuali decisioni prese durante l'implementazione non pre-specificate nel PRD
     - Cosa il milestone 9 dovrà sapere (in particolare: come la pagina pubblica espone le criticità del subset, dove agganciare l'embedding video)
     - Eventuali scostamenti dal PRD e perché

Fammi qualsiasi domanda di chiarimento usando lo strumento AskUserQuestion per definire il piano di implementazione di questo milestone.
