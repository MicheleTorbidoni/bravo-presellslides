# Milestone 2 — Setup & profilazione interna

Stai entrando in plan mode per pianificare e poi costruire il milestone 2 di questo progetto.

## Contesto

- Leggi `@_build_plan/prd.md` per il contesto completo del progetto: scope, modello dati e stack tecnologico.
- Leggi le cartelle dei milestone precedenti (`@_build_plan/milestones/1-fondamenta-contenuti/milestone-log.md`) per capire cosa è già stato costruito.

### Fondamenta già pronte da M1 (non ricostruirle)

- **Modello `PresaleSession`** persistito + endpoint **già esistenti**: `POST /presale_sessions` (crea, redirect Inertia) e `PATCH /presale_sessions/:id` (**auto-save**, va chiamato via `fetch` raw → risponde `head :ok`, non via router Inertia). Accetta già `company_name`, `contact_name`, `segment`, `operational_profile`, `discussed_criticalities`, `status`.
- **Loader `ContentConfig`**: usa `ContentConfig.segments` (7 segmenti id+label), `.decision_tree` (5 domande + salti), `.mappings` (lookup `segment × operationalProfile`), `.criticalities` (label). Non rileggere i JSON a mano.

### Decisione aperta che M2 DEVE chiudere (sollevala con l'utente in plan mode)

- **Leaf ↔ `operational_profile`**: oggi `decision-tree.json` usa profili placeholder (`profilo-1`, `profilo-2`, `profilo-b`) sulle risposte terminali, e `mappings.json` usa quelle stesse chiavi. Ma con i salti condizionali (D2 solo se D1=NO; D5 solo se D4=SI) esistono fino a **18 percorsi-foglia distinti**. Prima di costruire la risoluzione delle criticità, definisci con l'utente **come il percorso completo di risposte determina il profilo operativo salvato** e usato come chiave nei mapping — e se serve aggiorna coerentemente sia `decision-tree.json` sia `mappings.json`.

## Il tuo compito

1. Pianifica l'implementazione **solo** del milestone 2 come definito nel PRD. Non pianificare né costruire nulla dei milestone successivi.
2. Dopo che l'utente ha confermato il piano, costruisci solo ciò che rientra nello scope del milestone 2.
3. Verifica il tuo lavoro rispetto ai criteri "Fatto quando" del milestone 2 nel PRD.
4. Al completamento, scrivi un `milestone-log.md` in questa cartella (`_build_plan/milestones/2-setup-profilazione/milestone-log.md`). Strutturalo così:
   - **Inizia con una sezione `## Novità nell'app` proprio in cima.** Un elenco puntato conciso e leggibile delle principali funzionalità rivolte all'utente aggiunte in questo milestone, scritto in modo che un revisore non tecnico possa vedere a colpo d'occhio le novità da aspettarsi. Inquadra ogni punto come una capacità che l'utente vedrà o potrà fare, non come un artefatto tecnico. Tienilo breve e scansionabile.
   - Poi includi le sezioni di dettaglio implementativo, utili all'agente del milestone successivo:
     - Cosa è stato costruito (file creati, modelli aggiunti, route aggiunte, ecc.)
     - Eventuali decisioni prese durante l'implementazione non pre-specificate nel PRD
     - Tutto ciò che il milestone successivo deve sapere
     - Eventuali scostamenti dal PRD e perché

Fammi qualsiasi domanda di chiarimento usando lo strumento AskUserQuestion per definire il piano di implementazione di questo milestone.
