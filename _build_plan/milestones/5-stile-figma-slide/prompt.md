# Milestone 5 — Stile Figma & template slide

Stai entrando in plan mode per pianificare e poi costruire il milestone 5 di questo progetto.

## Contesto

- Leggi `@_build_plan/prd.md` per il contesto completo del progetto: scope, modello dati e stack tecnologico.
- Leggi le cartelle dei milestone precedenti (`@_build_plan/milestones/1-*/milestone-log.md` … `@_build_plan/milestones/4-*/milestone-log.md`) per capire cosa è già stato costruito.
- **Nota UI critica:** questo milestone riveste le superfici UI **custom** mostrate al prospect (hub e pagina di chiusura di M3, player slide di M4) — componenti React autonomi che **non** importano nulla dal design system del template. Qui cambia solo la veste grafica, non il comportamento.
- **Convenzione architetturale da introdurre:** "chrome stilizzato + contenuto PNG trasparente". La cornice React (sfondo, contenitore titolo, area body, logo) è stilizzata dai token Figma e ospita il testo **live** con le variabili `{{company_name}}` / `{{contact_name}}`; il contenuto visivo della slide è una **PNG trasparente** caricata per slide e per segmento, composita nella cornice — così non si aggancia uno stile Figma a ogni elemento dinamico.
- **Dipendenza:** ti serve il riferimento Figma reale (URL del file o token esportati) per derivare colori, tipografia, spaziature e layout. Se non è disponibile, chiedilo.

## Il tuo compito

1. Pianifica l'implementazione **solo** del milestone 5 come definito nel PRD. Non pianificare né costruire nulla dei milestone successivi.
2. Dopo che l'utente ha confermato il piano, costruisci solo ciò che rientra nello scope del milestone 5.
3. Verifica il tuo lavoro rispetto ai criteri "Fatto quando" del milestone 5 nel PRD.
4. Al completamento, scrivi un `milestone-log.md` in questa cartella (`_build_plan/milestones/5-stile-figma-slide/milestone-log.md`). Strutturalo così:
   - **Inizia con una sezione `## Novità nell'app` proprio in cima.** Un elenco puntato conciso e leggibile delle principali funzionalità rivolte all'utente aggiunte in questo milestone, scritto in modo che un revisore non tecnico possa vedere a colpo d'occhio le novità da aspettarsi. Inquadra ogni punto come una capacità che l'utente vedrà o potrà fare, non come un artefatto tecnico. Tienilo breve e scansionabile.
   - Poi includi le sezioni di dettaglio implementativo, utili all'agente del milestone successivo:
     - Cosa è stato costruito (file creati, modelli aggiunti, route aggiunte, ecc.)
     - Eventuali decisioni prese durante l'implementazione non pre-specificate nel PRD
     - Tutto ciò che il milestone successivo deve sapere
     - Eventuali scostamenti dal PRD e perché

Fammi qualsiasi domanda di chiarimento usando lo strumento AskUserQuestion per definire il piano di implementazione di questo milestone.
