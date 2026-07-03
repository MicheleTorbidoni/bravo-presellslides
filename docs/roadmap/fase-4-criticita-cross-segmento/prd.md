# Bravo Manufacturing Pre-Sale Tool — Fase 4: Criticità cross-segmento

> **Informazioni su questi file di roadmap:** questa cartella (`docs/roadmap/fase-4-criticita-cross-segmento/`) contiene il PRD e il prompt della **Fase 4** dell'app, un incremento costruito **sopra** i milestone già rilasciati (fino a M13). A differenza di `_build_plan/` (lo scaffold iniziale, destinato alla cancellazione), questa cartella documenta un'evoluzione del prodotto a partire dal codice esistente. Resta comunque un artefatto di guida: nessun codice, configurazione o logica di runtime deve importare o dipendere da questi file. La fonte di verità è il codice.

## Cosa stiamo costruendo

All'avvio di una call, la lista di criticità che Loredana (operatrice) prepara nel **Setup** è limitata al subset del **segmento industriale del prospect**. La mail con cui chiediamo al prospect di indicare le criticità da approfondire sta per introdurre un campo libero "oppure?", con cui il prospect può proporre criticità **fuori dal subset del suo segmento**.

La Fase 4 dà a Loredana un modo per portare quelle criticità nella call: nel Setup può **sfogliare le criticità di un altro segmento e aggiungerne alcune** al subset di **questa singola call**. L'aggiunta è per-sessione (persistita con l'auto-save esistente, sopravvive ai reload) e **non tocca la configurazione statica globale** (catalogo e mapping restano invariati) né altre call — "finita la call torna tutto come prima".

L'app è Rails 8 + React 19 + Inertia. La Fase 4 è un singolo milestone (M14) costruito sul modello dati e sulle superfici già esistenti.

### Cosa fa l'app (novità della Fase 4)

- Nel Setup, sotto la lista "Criticità da discutere", compare un pannello **"Aggiungi criticità da un altro segmento"**.
- Un menù a tendina elenca i segmenti industriali **meno** quello attualmente indicato per il prospect.
- Scelto un segmento alternativo, si vedono **tutte** le sue criticità; sono **aggiungibili solo quelle diverse** da quelle già presenti nel subset del segmento del prospect (e non già aggiunte). Le altre appaiono disabilitate ("Già presente" / "Aggiunta").
- Ogni criticità aggiungibile ha un pulsante **"Aggiungi"** che la porta nella lista della call.
- Una criticità extra è **identica alle altre** — checkbox on/off e trascinamento per l'ordine — con in più un **badge del segmento di origine** e una **"X" per rimuoverla**.
- Durante la call la criticità extra compare regolarmente nell'hub del prospect e, quando entra nel flusso, mostra le **slide verticalizzate del segmento di origine**.
- Se la criticità extra viene discussa, compare anche nella pagina di **recap** post-call (con il video di approfondimento risolto sul segmento di origine).
- Cambiare il segmento industriale del prospect **azzera** le criticità extra aggiunte (coerente con il reset già in essere alla selezione del segmento).

### Già fornito dal codice esistente (da riusare, non ri-specificare)

- **Subset per segmento**: `ContentConfig.criticalities_for_segment` e la catena `effective_selected_ids` / `effective_criticalities_order` in `PresaleSessionsController` (oggi fanno `& segment_ids`: è il punto in cui gli id fuori segmento vengono scartati).
- **Tutti i segmenti già lato client**: il Setup riceve già `criticalitiesBySegment` con le criticità di **ogni** segmento — il picker "altro segmento" non richiede nuove sorgenti dati.
- **Risoluzione contenuto verticalizzata**: `ContentConfig.steps_for` e `video_url_for` risolvono già per (segmento, token) con fallback ai condivisi.
- **UI**: drag-and-drop `@dnd-kit` in `Setup.tsx` con `SortableCriticality`, primitive `Badge` e `Select` del design system.
- **Superfici a valle**: `present`, `result`, `debrief` derivano già dai criticità effettivi via `effective_selected_ids` / `discussed_criticalities`, quindi ereditano gli extra senza modifiche dedicate.

### Fuori scope (Fase 4)

- Nessuna modifica al catalogo statico (`criticalities.json`) né ai `mappings.json`: nessun "spostamento" reale tra segmenti, nessuna lista globale separata.
- Nessuna persistenza cross-call o modifica permanente: gli extra vivono solo sulla singola `PresaleSession`.
- Il campo "oppure?" nella mail HubSpot e il parsing del testo libero del prospect: qui è **Loredana a decidere manualmente** cosa aggiungere. L'automazione inbound resta fuori.
- Nessuna gestione di profili operativi specifici del segmento di origine: la risoluzione del contenuto usa l'`operational_profile` della sessione (i token dell'albero sono globali).

### Modello dati

**PresaleSession (campo aggiunto)**

- **extra_criticalities** — elenco delle criticità aggiunte manualmente da altri segmenti per questa call. Per ogni voce si ricorda **quale criticità** (id) e **da quale segmento** proviene, perché il segmento di origine serve sia a mostrare il badge sia a risolvere le slide/il video verticalizzati. Vuoto di default; azzerato quando cambia il segmento del prospect.

---

## Milestone M14 — Criticità extra da altri segmenti

Loredana, nel Setup, può aggiungere alla call criticità prese da segmenti diversi da quello del prospect; le criticità aggiunte si comportano come le altre in tutta la call e nel recap.

### Cosa viene costruito

- **Pannello "Aggiungi da un altro segmento"** nel Setup: menù a tendina dei segmenti (escluso quello del prospect), elenco delle criticità del segmento scelto, con "Aggiungi" abilitato solo per quelle non già nel subset corrente né già aggiunte.
- **Integrazione nella lista principale**: le criticità extra appaiono come righe normali (checkbox, drag) con badge del segmento di origine e "X" di rimozione; concorrono a selezione e ordine.
- **Persistenza per-call**: le extra vengono salvate sulla sessione con l'auto-save esistente e sopravvivono ai reload; cambiare il segmento del prospect le azzera.
- **Propagazione alla call**: le criticità extra compaiono nell'hub del prospect e, nel flusso, mostrano le slide del **segmento di origine**.
- **Recap coerente**: una criticità extra discussa compare nella pagina di recap con il proprio video di approfondimento risolto sul segmento di origine.

### Cosa la milestone M14 esplicitamente NON include

- Nessuna automazione della mail/HubSpot né lettura del campo "oppure?" del prospect.
- Nessuna modifica ai file di configurazione statici (criticità, segmenti, mapping).
- Nessuna condivisione degli extra tra sessioni diverse.
- Nessun nuovo controllo lato hub/prospect: gli extra passano dal meccanismo già esistente.

### Done when

Nel Setup, con un segmento selezionato, Loredana apre il pannello "altro segmento", vede che le criticità già nel subset non sono aggiungibili, ne aggiunge una da un altro segmento e la trova nella lista con badge e possibilità di ordinarla/rimuoverla; avviando la presentazione la criticità extra compare nell'hub e mostra le slide del segmento di origine; cambiando il segmento del prospect gli extra spariscono. La suite `bin/rails test` passa al 100%.
