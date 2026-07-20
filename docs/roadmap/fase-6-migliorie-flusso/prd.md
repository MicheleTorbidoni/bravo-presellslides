# Bravo Manufacturing Pre-Sale Tool — Fase 6: Migliorie di flusso

> **Informazioni su questi file di roadmap:** questa cartella (`docs/roadmap/fase-6-migliorie-flusso/`) contiene il PRD e i prompt della **Fase 6** dell'app, un incremento costruito **sopra** i milestone già rilasciati (fino a M16, Fase 5). A differenza di `_build_plan/` (lo scaffold iniziale, destinato alla cancellazione), questa cartella documenta un'evoluzione del prodotto a partire dal codice esistente. Resta comunque un artefatto di guida: nessun codice, configurazione o logica di runtime deve importare o dipendere da questi file. La fonte di verità è il codice.

## Cosa stiamo costruendo

Il prodotto è in produzione e funzionante: questa fase raccoglie tre migliorie di flusso emerse dall'uso reale con Loredana.

Oggi il questionario di qualificazione commerciale (Fase 5) è troppo lungo e viene posto tutto prima delle slide. Lo **spezziamo in due momenti**: le domande che definiscono le criticità da presentare e alcune domande di contesto restano prima delle slide; le domande puramente anagrafiche/commerciali (organico, fatturato) si spostano **dopo** la presentazione, quando Loredana può introdurle con naturalezza ("prima di chiudere devo completare la tua scheda"); tre gruppi di domande che si sono rivelati poco utili vengono **eliminati**.

Questo split richiede anche di **riordinare il flusso operatore**: il primo questionario (quello che definisce le criticità) deve avvenire **prima** che l'operatore scelga le criticità da mostrare, così che la scelta tenga conto delle risposte tecniche del prospect, non alla cieca. Concretamente, la schermata di **Setup** viene mostrata **due volte**: una versione "leggera" appena creata la sessione (nome azienda/contatto, segmento, eventuali criticità — il minimo per orientarsi e passare al questionario), poi il **Questionario A**, poi di nuovo Setup — questa volta "completo" (riordino, criticità da altri segmenti, toggle di presentazione), con tutto il quadro ormai chiaro. Un secondo questionario ("Questionario B", solo le domande anagrafiche rimaste) si inserisce poi tra la fine della presentazione e i risultati. Questo doppio passaggio su Setup garantisce anche che **ogni** sessione — creata a mano o generata da HubSpot (reale o simulato) — passi sempre dal questionario: qualunque punto di ingresso porta alla stessa `/setup`, che decide da sola se mostrarsi leggera o completa in base allo stato della sessione.

Infine, ogni criticità guadagna una **slide finale con un video di approfondimento** pubblicato su YouTube/Vimeo, mostrata in coda alla sequenza di slide di quella criticità nel flusso live davanti al prospect — non solo nel recap via email come già accade oggi.

L'app resta Rails 8 + React 19 + Inertia, nessuna nuova integrazione esterna. La Fase 6 è costruita in **due milestone** (M17 riordino flusso + split questionario, M18 video finale per criticità): il primo milestone è il più ampio perché split e riordino sono la stessa modifica architetturale (la nuova schermata "Questionario B" è letteralmente dove finiscono le domande spostate); il video è indipendente e viene dopo.

---

### Cosa fa l'app (novità della Fase 6)

- Il questionario di qualificazione si presenta ora in **due schermate separate**: una prima del Setup (con le domande-criticità e alcune domande di contesto), una dopo la presentazione (solo le domande anagrafiche/aziendali rimaste).
- Tre gruppi di domande di qualificazione (Motivazione del contatto, Obiettivi di business, Aspettative) **spariscono** dal questionario: non vengono più poste in nessuna fase.
- L'ordine delle schermate operatore cambia: creazione sessione → **Setup (leggero)** → **Questionario A** → **Setup (completo)** → **Presentazione** → **Questionario B** → **Risultati**. Setup è la stessa schermata in entrambi i passaggi: mostra solo l'essenziale (azienda/contatto/segmento/criticità) la prima volta, e tutte le sezioni avanzate (riordino, criticità da altri segmenti, toggle intro/hub) la seconda, quando il questionario ha già dato un quadro completo.
- In Setup (completo), le criticità proposte di default all'operatore (badge "suggerita") tengono conto anche del profilo operativo emerso dal Questionario A, oltre ai suggerimenti già indicati dal prospect via HubSpot.
- La schermata di Chiusura della presentazione (mostrata al termine, prima dei risultati) porta ora a "Completa scheda" (Questionario B) invece che direttamente al riepilogo.
- Ogni criticità, nel flusso live davanti al prospect, termina con una **slide video** a schermo quasi intero: un player cliccabile con il video di approfondimento di quella criticità (o un placeholder se il video non è ancora stato pubblicato).

---

### Già fornito dal codice esistente (da riusare, non ri-specificare)

- **`content/config/questionnaire.json`** e il rendering a gruppi in `Profiling.tsx` (Fase 5): struttura a gruppi ordinati, ognuno con voci `{ ref: }` (domanda-criticità, stile accent) o campi extra inline (`field`, `label`, `type`, `options`, `visible_if`, `autosum`); toggle "Mostra solo domande per le criticità"; gate "Avanti" legato al solo walk dell'albero decisionale (`walkProfile`, `enabledIds`); auto-save debounced + ripristino via `apiPatch`.
- **`content/config/decision-tree.json`** — l'albero d1-d5, segment-agnostico: nessuna modifica necessaria, il Questionario A può precedere la scelta del segmento in Setup senza problemi.
- **`content/config/mappings.json`** — 126 righe (7 segmenti × 18 profili operativi `operationalProfile`), oggi ognuna con lo stesso set di `criticalities` per tutti i profili di un segmento (nessuna differenziazione reale ancora — vedi nota nel milestone M17).
- **`ContentConfig.criticalities_for_segment`** — unione di tutte le righe di un segmento; resta usato per il subset "ammesso" (`allowed_ids` nel controller). Serve un lookup nuovo, più specifico, sulla singola riga segmento+profilo.
- **`content/config/videos.json` + `ContentConfig.video_url_for` + `app/lib/video_embed.rb` (`VideoEmbed`)** — già usati in `PublicRecapsController` per il recap pubblico: risolvono l'URL del video di una criticità con override per segmento/token, e lo convertono in un embed YouTube-nocookie/Vimeo. Stessa identica risoluzione da riusare nel flusso live.
- **`app/frontend/components/present/{SlidePlayer,Stage,Closing}.tsx`** — lo `Stage` 16:9 condiviso, il pattern "step" con `title`/`body`/`phases` e placeholder su immagine mancante (`SlideImage`), il pattern onClick-per-avanzare di `Present.tsx` (`advance`/`completeFlow`).
- **`app/javascript/pages/PresaleSessions/Setup.tsx`** — selezione segmento/criticità, drag-and-drop ordine, badge "suggerita" (`isSuggested`), auto-save pattern.
- **`PresaleSessionsController`** — `effective_selected_ids`, `effective_criticalities_order`, `steps_by_criticality`: punti di estensione per il nuovo lookup segmento+profilo e per l'aggiunta dello step-video.

---

### Fuori scope (Fase 6)

- **Differenziare realmente le 126 righe di `mappings.json` per profilo operativo**: resta un compito di content-authoring futuro. Il nuovo lookup segmento+profilo in Setup è pronto a consumare questa differenziazione ma, finché le righe restano identiche per ogni profilo di un segmento, il suo effetto pratico sui suggerimenti è nullo — comportamento atteso, non un difetto di questa fase.
- **Migrazione o pulizia dei dati storici** delle sessioni già compilate per i gruppi di questionario eliminati (Motivazione, Obiettivi, Aspettative): le chiavi restano nel jsonb `qualification_answers` ma vengono semplicemente ignorate/non più mostrate in nessuna schermata.
- **Riordino dei gruppi del questionario da interfaccia**: resta guidato dal file `content/config/questionnaire.json`, come oggi — nessun editor a schermo.
- **Un modo per saltare il Questionario B** direttamente ai Risultati dalla Chiusura: il passaggio da Questionario B è ora l'unica via.
- **Autoplay o controlli avanzati del player video** (sottotitoli, selezione qualità, velocità di riproduzione) e **analytics di visione**: resta il player embed standard (YouTube-nocookie/Vimeo) già usato nel recap, in modalità click-to-play.
- **Sync delle risposte del questionario con HubSpot**: già fuori scope dalla Fase 5, resta tale.

---

### Modello dati

Nessuna nuova tabella o colonna. La Fase 6 riusa integralmente lo stato esistente:

- **PresaleSession** — `segment`, `operational_profile`, `selected_criticalities`, `criticalities_order`, `suggested_criticalities`, `qualification_answers` (jsonb): tutti già esistenti, nessun campo nuovo. La distinzione fase 1/fase 2 del questionario è puramente una questione di **quali gruppi mostra ciascuna schermata**, non un nuovo stato persistito — le risposte di entrambe le fasi continuano a confluire nella stessa mappa `qualification_answers`.
- **Config statica** — `content/config/questionnaire.json` viene riorganizzato (gruppi spostati/rimossi, vedi Appendice B) ma resta lo stesso file con la stessa forma; `content/config/mappings.json` e `content/config/videos.json` restano invariati nella forma, riusati com'è.

---

## Milestone M17 — Riordino del flusso e questionario in due fasi

Setup viene mostrato due volte (leggero prima del Questionario A, completo dopo), introduce una nuova schermata "Questionario B" dopo la presentazione, e riorganizza `questionnaire.json` secondo l'Appendice B. Split e riordino sono la stessa modifica: la nuova schermata B è dove atterrano le domande spostate.

### Cosa viene costruito

- **`content/config/questionnaire.json` riorganizzato** secondo l'Appendice B: i gruppi Interlocutore, Produzione & macchine, Gestione & software, Criticità attuali, Miglioramenti desiderati restano (quest'ultimi due, pur non definendo criticità, restano in fase 1 per scelta esplicita); nuovo gruppo **"Terziarizzazione"** (conto terzi, % conto terzi, outsourcing, oggi dentro "Azienda"); il gruppo **Azienda** si riduce alle sole domande su organico e fatturato e diventa il contenuto della fase 2; i gruppi **Motivazione del contatto**, **Obiettivi di business**, **Aspettative** vengono **rimossi** interamente (campo e relativi "Altro" condizionali).
- **Setup mostrato due volte, stessa route**: `PresaleSessionsController#create` continua a reindirizzare a `/setup` (nessun cambiamento qui — è il punto d'ingresso, sia per la creazione manuale sia per qualunque sessione generata da HubSpot/simulatore). Setup stesso decide se mostrarsi **leggero** o **completo** in base alla presenza di `operational_profile` sulla sessione (non ancora impostato = leggero, prima del questionario; già impostato = completo, dopo):
  - **Leggero**: solo azienda/contatto/segmento e un elenco piatto delle criticità (abilita/disabilita, nessun riordino, nessuna aggiunta da altri segmenti, nessun toggle intro/hub). La selezione delle criticità è **facoltativa** qui — basta il segmento per procedere. Il bottone "Avanti" porta a `/profiling`.
  - **Completo**: tutte le sezioni di oggi (riordino drag&drop, "aggiungi criticità da un altro segmento", toggle intro/hub), gate invariato (segmento + almeno una criticità abilitata). Il bottone "Avanti" porta a `/present`.
- **Questionario A** (`/profiling`, invariato rispetto a prima di questa revisione): gate legato al solo completamento dell'albero decisionale; "Avanti" porta di nuovo a `/setup` (che questa volta si mostra completo, avendo ormai `operational_profile` impostato).
- **Criticità suggerite in Setup (completo)**: il default (badge "suggerita", che pre-seleziona le criticità abilitate) diventa l'**unione** tra il segnale HubSpot esistente (`suggested_criticalities` intersecato col segmento) e un nuovo lookup su `mappings.json` per la riga specifica segmento+profilo operativo (`operational_profile` prodotto dal Questionario A), sempre **clampato** al segmento. L'operatore può sempre deselezionare o aggiungere criticità a mano, come oggi. Il badge resta legato al solo segnale HubSpot.
- **Nuova schermata "Questionario B"**: nuova route/azione dedicata (es. `GET /presale_sessions/:id/qualification`) che riusa il rendering a gruppi di `Profiling.tsx` ma mostra **solo** il gruppo Azienda ridotto (fase 2), senza alcun gate di completamento. Un solo bottone finale ("Vai al riepilogo") porta direttamente a `/result`; nessun bottone "Indietro".
- **Schermata di Chiusura** (`Closing.tsx`, prospect-facing): il bottone "Vai al riepilogo" viene **sostituito** da "Completa scheda", che porta alla nuova schermata Questionario B. "Torna all'hub" resta invariato.
- **Elenco sessioni** (`Index.tsx`): il bottone "Riprendi" di una sessione attiva punta sempre a `/setup`, che si occupa da sola di mostrarsi leggero o completo — nessuna logica di instradamento duplicata nell'elenco.
- **Test** (controller: redirect e nuova route; config: struttura di `questionnaire.json` post-riorganizzazione; system test della UX end-to-end Setup(leggero)→A→Setup(completo)→Present→B→Result, e delle due modalità di Setup) e **screenshot** desktop + mobile delle schermate toccate.

### Cosa il milestone M17 esplicitamente NON include

- **Nessuna differenziazione reale delle 126 righe di `mappings.json`**: il lookup segmento+profilo va implementato e cablato, ma il contenuto del file resta quello attuale (stesso set di criticità per ogni profilo di un segmento) — l'effetto visibile su Setup sarà nullo finché qualcuno non modifica manualmente il file.
- **Nessuna migrazione dei dati storici** delle sessioni già compilate per i gruppi rimossi.
- **Nessuna modifica alla logica dei token/criticità** (`decision-tree.json`, gate "Avanti" del Questionario A): resta identica, solo la sua posizione nel flusso cambia.
- **Nessun modo di saltare il Setup leggero** anche quando i dati arrivano già completi da HubSpot: si mostra sempre, per ogni sessione, senza casi speciali.
- **Video finale per criticità**: milestone M18.

### Done when

Creando una nuova sessione (a mano o da HubSpot/simulatore), si atterra su Setup **leggero** (solo azienda/contatto/segmento/criticità facoltative); procedendo si passa al Questionario A (Interlocutore, Produzione & macchine, Gestione & software, Terziarizzazione, Criticità attuali, Miglioramenti desiderati — non più i tre gruppi rimossi); completandolo si torna su Setup, questa volta **completo** (riordino, extra da altri segmenti, toggle intro/hub, criticità suggerite arricchite dal profilo operativo); da qui si entra nella presentazione; alla Chiusura il bottone porta al Questionario B (solo il gruppo Azienda ridotto); completandolo si arriva ai Risultati. La suite `bin/rails test` passa al 100% e `npm run check` è pulito.

---

## Milestone M18 — Video finale per criticità

Aggiunge, in coda al flusso live di ogni criticità, una slide con il video di approfondimento già configurato in `content/config/videos.json` e già usato nel recap pubblico.

### Cosa viene costruito

- **Step video sintetico** aggiunto in coda alla sequenza di ogni criticità (accanto a `ContentConfig.steps_for`/`steps_by_criticality`), risolto con la stessa identica logica già usata da `PublicRecapsController` (`ContentConfig.video_url_for` + `VideoEmbed.url`, override segmento/token invariati).
- **Layout fullscreen**: nello `Stage` 16:9 condiviso, questa slide mostra solo il player video + il logo Bravo in overlay — niente titolo/corpo testo, a differenza delle altre slide.
- **Riproduzione click-to-play**: il player mostra la thumbnail e parte solo al click esplicito sul video; il click sul resto dello stage / il tasto → restano il modo per avanzare alla criticità successiva (o all'hub), come su ogni altra slide.
- **Placeholder "Video non disponibile"** quando l'URL configurato non risolve a un embed valido (oggi il caso per ogni criticità, essendo tutti placeholder testuali in `videos.json`) — stesso trattamento visivo già usato da `SlideImage` per le immagini bitmap mancanti.
- **Test** (risoluzione dell'URL nel contesto segmento/token, rendering placeholder vs player) e **screenshot** desktop + mobile.

### Cosa il milestone M18 esplicitamente NON include

- **Autoplay**, controlli avanzati del player (sottotitoli, qualità, velocità), o qualunque analytics di visione.
- **Nuova infrastruttura di config per i video**: `videos.json` resta identico nella forma; solo il suo consumo si estende al flusso live oltre che al recap.
- **Contenuti video reali**: gli URL restano placeholder finché non vengono sostituiti a mano nel file — non è compito di questo milestone popolarli.

### Done when

Percorrendo una criticità fino in fondo nel flusso live, dopo l'ultimo step di contenuto compare una slide fullscreen con il player video (cliccabile per avviare la riproduzione) oppure, se l'URL non è ancora valido, un placeholder "Video non disponibile" — in entrambi i casi il tasto → (o un click) prosegue verso la criticità successiva o l'hub. La suite `bin/rails test` passa al 100%.

---

## Appendice B — Struttura finale di `questionnaire.json` (fonte di verità in-repo)

Gruppi in ordine di visualizzazione. 🔶 = domanda-criticità (`{ "ref": "…" }`, invariata). *(F1)* = fase 1 (`/profiling`, prima del Setup). *(F2)* = fase 2 (nuova schermata Questionario B, dopo la presentazione). *(rimosso)* = eliminato del tutto.

### 1. Interlocutore *(F1, invariato)*
- **contact_roles** — scelta multipla — invariato
- **contact_role_other** — testo, *visible_if* Altro — invariato

### 2. Produzione & macchine *(F1, invariato — definisce criticità)*
- 🔶 **ref d1** — invariato
- 🔶 **ref d2** — invariato

### 3. Gestione & software *(F1, invariato — definisce criticità)*
- 🔶 **ref d3** — invariato
- **production_management_software_name** — *visible_if* ref d3 = mrp — invariato
- 🔶 **ref d4** — invariato
- 🔶 **ref d5** — invariato

### 4. Terziarizzazione *(F1, nuovo gruppo — separato da "Azienda")*
- **does_subcontract_manufacturing** — "Svolgete lavorazioni conto terzi?" — sì/no
- **subcontract_turnover_percentage** — "Quanto incidono sul fatturato?" — percentuale — *visible_if:* `does_subcontract_manufacturing` = sì
- **does_outsource_work** — "Affidate alcune lavorazioni in outsourcing?" — sì/no

### 5. Criticità attuali *(F1, invariato)*
- **current_issue_categories** — scelta multipla — invariato
- **current_issue_other_text** — testo lungo, *visible_if* Altro — invariato

### 6. Miglioramenti desiderati *(F1, invariato)*
- **desired_improvement_categories** — scelta multipla — invariato
- **desired_improvement_other_text** — testo lungo, *visible_if* Altro — invariato

### 7. Azienda *(F2 — ridotto, contenuto della nuova schermata Questionario B)*
- **production_operators_count** — intero
- **technical_office_people_count** — intero
- **administrative_people_count** — intero
- **other_office_people_count** — intero
- **total_people_count** — intero — auto-somma dei quattro precedenti, sovrascrivibile a mano
- **annual_turnover_amount** — valuta

### Motivazione del contatto *(rimosso)*
- ~~contact_reason_categories~~, ~~contact_reason_other_text~~ — rimossi interamente

### Obiettivi di business *(rimosso)*
- ~~business_goal_categories~~, ~~business_goal_other_text~~ — rimossi interamente

### Aspettative *(rimosso)*
- ~~mes_expectations_text~~ — rimosso interamente
