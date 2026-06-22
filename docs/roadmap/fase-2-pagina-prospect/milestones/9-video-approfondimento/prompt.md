# Milestone 9 — Video di approfondimento nella pagina

Stai entrando in plan mode per pianificare e poi costruire il milestone 9 di questo progetto (secondo e ultimo milestone della Fase 2).

## Contesto

- Leggi `@docs/roadmap/fase-2-pagina-prospect/prd.md` per il contesto completo della Fase 2: scope, modello dati, fondamenta esistenti da riusare.
- Leggi il log del milestone precedente di questa fase (`@docs/roadmap/fase-2-pagina-prospect/milestones/8-*/milestone-log.md`) per capire com'è fatta la pagina pubblica del prospect e come espone le criticità del subset — questo milestone vi aggiunge i video.
- Per il contesto di base leggi anche i log dei 7 milestone iniziali (`@_build_plan/milestones/*/milestone-log.md`), in particolare la convenzione varianti per token/segmento e la risoluzione contenuti.
- Riusa `ContentConfig.video_url_for` (risoluzione del video per segmento × profilo operativo, già esistente) invece di reintrodurre logica di selezione.

## Il tuo compito

1. Pianifica l'implementazione **solo** del milestone 9 come definito nel PRD. Essendo il milestone finale della Fase 2, non pianificare lavoro oltre il suo scope.
2. Dopo che l'utente ha confermato il piano, costruisci solo ciò che rientra nello scope del milestone 9.
3. Verifica il tuo lavoro rispetto ai criteri "Fatto quando" del milestone 9 nel PRD.
4. Al completamento, scrivi un `milestone-log.md` in questa cartella (`docs/roadmap/fase-2-pagina-prospect/milestones/9-video-approfondimento/milestone-log.md`). Strutturalo così:
   - **Inizia con una sezione `## Novità nell'app` proprio in cima.** Un elenco puntato conciso e leggibile delle principali funzionalità rivolte all'utente aggiunte in questo milestone, scritto in modo che un revisore non tecnico possa vedere a colpo d'occhio le novità. Inquadra ogni punto come una capacità che l'utente vedrà o potrà fare, non come un artefatto tecnico. Tienilo breve e scansionabile.
   - Poi includi le sezioni di dettaglio implementativo (milestone finale — comunque utili per la manutenzione futura):
     - Cosa è stato costruito (file creati, route aggiunte, modifiche a `videos.json`, ecc.)
     - Eventuali decisioni prese durante l'implementazione non pre-specificate nel PRD
     - Eventuali scostamenti dal PRD e perché

Fammi qualsiasi domanda di chiarimento usando lo strumento AskUserQuestion per definire il piano di implementazione di questo milestone.
