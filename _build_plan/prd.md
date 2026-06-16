# Bravo Manufacturing Pre-Sale Tool

> **Informazioni su questi file di build-plan:** Tutto ciò che si trova in `_build_plan/` (questo PRD e le cartelle per-milestone) è un **artefatto temporaneo di documentazione e guida** per la costruzione iniziale di questo codebase. Questi file non sono funzionali — nessun codice, configurazione, logica di runtime, test o processo di deploy deve importare, leggere, referenziare o dipendere da qualcosa dentro `_build_plan/`. Una volta che i milestone iniziali sono costruiti e rilasciati, l'intera cartella `_build_plan/` è destinata a essere eliminata. Non trattarla come documentazione di lungo periodo.

## Cosa stiamo costruendo

**Bravo Manufacturing Pre-Sale Tool** è un'applicazione web interna che guida un operatore pre-sale di Antos SRL (utente tipo: Loredana) durante una call conoscitiva con un cliente prospect, costruendo dinamicamente una presentazione su misura.

L'app combina tre dimensioni per comporre la sessione: il **segmento industriale** del prospect (determina quale variante di screenshot/grafica viene mostrata), il suo **profilo operativo** (determina quali criticità sono rilevanti) e le **criticità selezionate** in tempo reale dall'operatore (determinano la sequenza di slide da mostrare). L'elemento differenziante rispetto a PowerPoint/Keynote è la capacità di riusare un unico set di flussi (le "criticità") e verticalizzare i contenuti visivi per segmento — qualcosa di impossibile o molto oneroso con strumenti di presentazione tradizionali.

La call avviene in streaming (Zoom/Meet) con condivisione schermo gestita via **OBS Studio**: è OBS a decidere quando mostrare l'app al prospect, quindi le schermate di profilazione vengono completate *prima* di avviare la condivisione. La sessione si chiude con un debrief e un recap inviabile via email al prospect; le sessioni vengono archiviate per essere riprese, ripulite e re-inviate in un secondo momento.

L'app è costruita sul template **Build New** (Rails 8 + React 19 via Inertia.js + Tailwind CSS v4 + PostgreSQL) ed è organizzata in 7 milestone incrementali, ognuno dei quali consegna funzionalità visibili e provabili in browser.

---

### Cosa fa l'app

- Permette all'operatore di **accedere** (area interna protetta) e avviare una nuova sessione di pre-sale.
- Raccoglie i dati del prospect (**nome azienda, nome contatto**) e il suo **segmento industriale** tra 7 opzioni.
- Conduce l'operatore attraverso un **decision tree** di 5 domande (con salti condizionali) che determina il **profilo operativo** del prospect — schermate riservate, non mostrate al prospect.
- **Risolve automaticamente** quali criticità (4-5 su 13 totali) sono rilevanti, leggendo una mappatura di configurazione.
- Mostra al prospect una **schermata hub** ("Dove fa più difficoltà la tua azienda?") con le criticità come pillole selezionabili in tempo reale.
- Riproduce una **presentazione a slide** 16:9 in fullscreen, con grafiche verticalizzate per segmento, slide animate a sequenza di step, e variabili personalizzate col nome del prospect.
- Consente di **catturare domande** del prospect durante la presentazione, legandole alla slide corrente.
- Produce un **debrief** con riepilogo e domande, e invia un **recap via email** al prospect.
- Mantiene un **archivio delle sessioni** per azienda/data, dove ripulire le domande e ri-inviare i recap anche in seguito.

---

### Già fornito dal template Build New

- **Autenticazione completa**: login, logout, registrazione autonoma (signup pubblico con rate-limit), reset password via email, cambio password dal profilo. Tutto mantenuto così com'è, zero lavoro custom.
- Modello **`User`** e creazione utenti (anche da console/seed).
- **Shell autenticata** e protezione delle route interne (`require_authentication`).
- **Design system** completo (token, primitive, dark mode, utility `cn()`, componenti sotto `components/ui/` e `components/design-system/`) — da usare **solo per le schermate interne**.
- **Coda di background job** (Solid Queue) — sfruttata per l'invio email.
- Pipeline **Inertia/SSR** e file di discovery (sitemap/robots/llms); poco rilevanti qui perché l'app è interna/autenticata.

---

### Fuori scope (MVP)

- **Integrazione HubSpot** (salvataggio recap nel CRM) — prevista come evoluzione futura, non nell'MVP.
- **Pannello di amministrazione** per la gestione contenuti — i contenuti si modificano via file JSON + re-deploy.
- **Analytics** sulle sessioni (segmenti più frequenti, criticità più discusse).
- **Multi-lingua** — l'app è solo in italiano.
- **Registrazione/replay** della sessione e **modalità offline**.
- **Account individuali / ruoli / multi-utenza** — per ora un account condiviso; architettura tenuta aperta a un'evoluzione futura.
- **Ottimizzazione mobile/touch** — è uno strumento desktop guidato via OBS.
- **UI di upload asset / storage su S3-R2** — le bitmap sono file statici nel repo; migrazione rimandata se crescono.
- **Editor visuale** del decision tree, dei mapping o delle slide — si editano i file JSON a mano.

---

### Modello dati

Il modello dati vive su tre livelli; solo uno tocca il database.

**1. Database (PostgreSQL) — persistito**

**Utente (`User`)** — già dal template, protegge l'accesso.
- email
- password
- *(MVP: un solo account condiviso dal team pre-sale)*

**Sessione di pre-sale** — il record durevole di una call. Si crea all'avvio della sessione e si aggiorna man mano (auto-save), così nulla va perso anche se il browser viene chiuso.
- nome azienda prospect
- nome contatto prospect
- segmento industriale selezionato (uno dei 7)
- profilo operativo identificato (il leaf node del decision tree)
- criticità discusse (quali tra quelle rilevanti sono state effettivamente affrontate)
- elenco delle domande catturate — per ciascuna: il testo, il riferimento alla slide/criticità in cui è stata posta, l'ora
- data/creazione della sessione
- stato (in corso / chiusa / recap inviato)

> Relazioni: ogni Sessione di pre-sale appartiene all'utente loggato che l'ha condotta. Le domande sono un elenco ricordato dentro la sessione.

**2. Stato di presentazione (in memoria, lato browser) — effimero, NON persistito**

L'esperienza di visione delle slide è puro stato di runtime e non viene salvata: quale slide/step si sta vedendo, lo stato fullscreen, le selezioni temporanee delle pillole prima del consolidamento. Si ricostruisce ad ogni apertura.

**3. Contenuti di configurazione (file statici nel repo) — NON database**

- `content/config/decision-tree.json` — le 5 domande, i salti condizionali, i leaf node
- `content/config/criticalities.json` — le 13 criticità con i loro metadati
- `content/config/mappings.json` — segmento × profilo operativo → ID delle criticità rilevanti
- `content/config/slides.json` — le slide per ciascuna criticità (tipi `concept` / `screenshot` / `sequence`)
- `content/assets/<segmento>/*.png` e `content/assets/common/*.png` — le bitmap statiche

---

## Milestone 1 — Fondamenta & contenuti

Pone le basi: l'impalcatura dei contenuti di configurazione, le cartelle asset con segnaposto, e il modello dati persistente della sessione con auto-save. Non c'è ancora un flusso utente visibile end-to-end, ma l'ossatura su cui poggiano tutti i milestone successivi è in piedi e verificabile.

### Cosa viene costruito

- Conferma che **login, shell autenticata e protezione delle route** del template funzionano per questa app.
- Struttura delle cartelle `content/config/` e `content/assets/` con le sottocartelle per i 7 segmenti + `common`.
- File di configurazione **JSON con dati placeholder ma strutturalmente validi**:
  - `decision-tree.json` con le 5 domande e i salti condizionali (D2 solo se D1=NO; D5 solo se D4=SI), leaf node = profilo operativo.
  - `criticalities.json` con tutte e 13 le criticità e i loro metadati.
  - `mappings.json` con alcune combinazioni segmento × profilo → criticità di esempio.
  - `slides.json` con slide d'esempio per qualche criticità, inclusi i tre tipi (`concept`, `screenshot`, `sequence`).
- **Bitmap placeholder** nelle cartelle asset, sufficienti a esercitare il caricamento per segmento e da `common`.
- Modello dati **Sessione di pre-sale** persistito, con **auto-save**: una sessione può essere creata e aggiornata e sopravvive alla chiusura del browser.

### Cosa il milestone 1 NON include

- Le schermate di setup, decision tree, hub, player, debrief o archivio (arrivano dai milestone successivi).
- Contenuti reali (testi e bitmap definitivi) — solo placeholder.
- L'invio email.

### Fatto quando

L'operatore può fare login ed entrare nell'area protetta; i file di configurazione vengono caricati senza errori; una sessione di pre-sale vuota può essere creata e ritrovata dopo aver chiuso e riaperto il browser.

---

## Milestone 2 — Setup & profilazione interna

Consegna l'intero flusso interno di pre-sessione (non mostrato al prospect): dall'inserimento dei dati del prospect alla determinazione del profilo operativo e del subset di criticità rilevanti.

### Cosa viene costruito

- **Schermata di setup** (design system del template) con i campi *nome azienda prospect* e *nome contatto prospect*, e la **selezione del segmento industriale** tra i 7 (griglia o lista di card cliccabili).
- **Decision tree**: schermate interne riservate all'operatore, una domanda alla volta, lette da `decision-tree.json`; le 5 domande con i **salti condizionali**; navigazione **avanti/indietro** per correggere.
- Al termine dell'albero, il sistema determina il **leaf node = profilo operativo**.
- **Risoluzione delle criticità rilevanti**: lookup su `mappings.json` con chiave segmento × profilo → subset di 4-5 criticità (nessuna logica di calcolo); fallback prevedibile se la combinazione non ha mapping.
- La **sessione viene creata e persistita** all'avvio (auto-save), popolata con azienda, contatto, segmento e profilo man mano che si avanza.

### Cosa il milestone 2 NON include

- La schermata hub "Dove fa più difficoltà" mostrata al prospect (milestone 3).
- Il player di slide e la cattura domande (milestone 4).
- Lo styling fedele a Figma del decision tree — verrà rifinito più avanti; per ora la resa funzionale è sufficiente.

### Fatto quando

L'operatore può inserire i dati del prospect, scegliere il segmento, rispondere alle 5 domande (con i salti corretti), e l'app determina e mostra il profilo operativo con il relativo subset di criticità rilevanti; la sessione risulta persistita con questi dati.

---

## Milestone 3 — Hub criticità & loop

Introduce il primo contesto UI **custom** (mostrato al prospect): la schermata centrale da cui si selezionano le criticità e si entra/esce dai flussi di presentazione.

### Cosa viene costruito

- Schermata hub con titolo **"Dove fa più difficoltà la tua azienda?"** e le criticità rilevanti pre-risolte come **pillole/tag cliccabili**.
- **Selezione/deselezione in tempo reale** durante la conversazione, con stato "selezionata" visivamente distinto.
- Pulsante **"Avvia presentazione" / "Continua"** che procede con le criticità selezionate.
- **Loop di ritorno**: completato il flusso di una criticità si rientra nell'hub; ogni criticità già discussa è **marcata come completata**; se ne può scegliere un'altra.
- **Pagina di chiusura fissa**, uguale per tutti i segmenti e profili (cambiano solo le variabili nome azienda/contatto), raggiungibile da qualunque punto tramite **scorciatoia da tastiera**, che conclude la conversazione e porta al debrief.
- Questo contesto UI è **autonomo**: componenti React separati che non importano nulla dal design system del template.

### Cosa il milestone 3 NON include

- Il rendering effettivo delle slide di contenuto (milestone 4) — qui basta poter entrare/uscire dal flusso anche con un player segnaposto.
- La cattura domande (milestone 4).
- Lo styling definitivo dai token Figma — comportamento funzionale prima, rifinitura visiva dopo (milestone 5).
- Riordino drag&drop, timer per criticità.

### Fatto quando

Con una sessione profilata, l'operatore vede l'hub con le criticità rilevanti, può selezionarle/deselezionarle, avviare un flusso, tornare all'hub con la criticità marcata come completata, e raggiungere la pagina di chiusura via scorciatoia.

---

## Milestone 4 — Slide player & cattura domande

Il cuore della presentazione: il player di slide a tutto schermo e la cattura delle domande del prospect.

### Cosa viene costruito

- **Player slide 16:9** che si adatta alla viewport mantenendo il ratio (letterbox se serve).
- **Modalità fullscreen** (Fullscreen API) con pulsante per attivarla/disattivarla.
- **Rendering della slide** da `slides.json`: titolo, corpo testuale, bitmap, e **variabili** `{{company_name}}` / `{{contact_name}}` sostituite coi dati del prospect.
- Caricamento **asset per segmento** (`assetIsSegmentVariant: true` → cartella del segmento) o da **`common`** (`false`).
- **Slide a sequenza** (`type: "sequence"`): l'avanti avanza di uno step alla volta dentro la slide e poi passa alla successiva (indietro speculare).
- **Navigazione tastiera e click**: → / click = avanti, ← = indietro, `F`/`F11` = toggle fullscreen, `Q` = apre la cattura domanda.
- Possibilità di **saltare a criticità successive** e di raggiungere la **pagina di chiusura** via scorciatoia.
- **Cattura domanda**: la scorciatoia `Q` apre un **overlay minimale** con campo di testo libero; alla conferma la domanda viene **salvata (persistita, auto-save)** e legata alla slide/criticità corrente; si possono catturare più domande.
- Logo Bravo Manufacturing presente nelle slide (collocazione/stile rifiniti in milestone 5).

### Cosa il milestone 4 NON include

- Lo stile Figma definitivo delle slide e i template per tipo (milestone 5) — qui la resa è funzionale, con placeholder.
- La modifica/cancellazione delle domande durante la presentazione — l'editing avviene dopo, nel debrief/archivio.
- Transizioni/animazioni avanzate oltre la sequenza di step, video/audio embeddati, telestrator (disegno sulle slide), presenter view separata.
- Il pulsante a schermo per la cattura domanda: si usa **solo** la scorciatoia `Q`.

### Fatto quando

Con contenuti placeholder, l'operatore riproduce la presentazione di una criticità in fullscreen, naviga avanti/indietro (incluse le slide a sequenza), vede le bitmap corrette per il segmento e le variabili col nome del prospect, e cattura una domanda con `Q` che risulta salvata e legata alla slide.

---

## Milestone 5 — Stile Figma & template slide

Veste grafica definitiva delle superfici mostrate al prospect: applica i token e i layout di Figma ai contesti UI custom di M3 e M4 (hub, pagina di chiusura, player slide) **senza cambiarne il comportamento**. Introduce la convenzione "chrome stilizzato + contenuto PNG trasparente" che separa la cornice riutilizzabile (titolo, body, logo, sfondo) dal contenuto visivo verticalizzato per segmento.

### Cosa viene costruito

- **Token e primitive Figma autonome** per il contesto prospect (colori, tipografia, spaziature, logo Bravo Manufacturing), separate dal design system del template.
- **Template stilizzati per i 3 tipi di slide** (`concept`, `screenshot`, `sequence`): ogni tipo ha una cornice Figma con contenitore titolo, area body opzionale e collocazione logo.
- **Modello "chrome + contenuto PNG"**: titolo e body sono **testo live** nella cornice React (con sostituzione `{{company_name}}` / `{{contact_name}}`); il contenuto visivo è una **PNG trasparente** caricata per slide e per segmento, composita nella cornice. Niente binding di stile su ogni elemento dinamico.
- **Rifinitura Figma dell'hub** ("Dove fa più difficoltà…") e della **pagina di chiusura** (M3): pillole, stati selezionata/completata, titoli e sfondo allineati ai token.
- Eventuale adeguamento di `slides.json` / convenzione asset (PNG trasparenti, eventuale campo template), mantenendo **retro-compatibile** il player M4.

### Cosa il milestone 5 NON include

- Nuovi comportamenti o flussi (hub, loop, player e cattura domande restano quelli di M3/M4 — qui cambia solo la veste).
- Lo stile delle schermate interne (setup, decision tree, debrief, archivio) — usano il design system del template.
- La produzione dei contenuti grafici definitivi (le PNG reali per segmento) — restano placeholder; qui si definisce il contenitore e la convenzione, non si disegnano gli screenshot.
- Animazioni/transizioni oltre la sequenza di step già esistente.

### Fatto quando

Con contenuti placeholder, l'hub, la pagina di chiusura e i 3 tipi di slide appaiono con la veste Figma; titolo e body mostrano le variabili col nome del prospect come testo live dentro la cornice stilizzata, mentre il contenuto è una PNG trasparente caricata per slide/segmento; il comportamento di M3/M4 è invariato.

---

## Milestone 6 — Debrief & email recap

Chiude la call: schermata di riepilogo e invio del recap via email al prospect.

### Cosa viene costruito

- Schermata **debrief** (design system del template) raggiungibile a fine call (dalla pagina di chiusura), con **riepilogo**: azienda + contatto, segmento + profilo operativo, criticità discusse, **domande catturate** (con riferimento a slide/criticità).
- Possibilità di **editare le domande** dal debrief (aggiungere, modificare il testo, rimuovere) — opera sullo stesso record della sessione.
- Pulsante **"Invia recap via email"** → **modale** con campo **destinatario** (pre-compilato o vuoto) e **corpo del recap editabile** prima dell'invio.
- **Invio one-shot via Resend** in produzione (mittente configurabile via variabile d'ambiente, default `loredana.mosca@antos.it`); in sviluppo locale si usano le **anteprime email** senza invio reale.
- Destinatario MVP = **prospect**, inserito manualmente.
- Dopo l'invio lo **stato** della sessione diventa "recap inviato".

### Cosa il milestone 6 NON include

- L'integrazione HubSpot.
- Destinatari multipli / CC al consulente (single recipient per ora).
- Tracking aperture/click, invii programmati, allegati, editor HTML ricco.
- La schermata archivio (milestone 7) — qui il debrief è quello immediato di fine call.

### Fatto quando

A fine call l'operatore vede il debrief con riepilogo e domande, può editare le domande, aprire la modale di invio, e inviare il recap al prospect (verificabile via anteprima email in locale); la sessione passa a stato "recap inviato".

---

## Milestone 7 — Archivio sessioni

Rende le sessioni consultabili e gestibili nel tempo, scollegando il debrief e l'invio recap dal momento live della call.

### Cosa viene costruito

- **Elenco delle sessioni** (design system del template) con azienda, contatto, data, segmento/profilo e **stato** (in corso / chiusa / recap inviato).
- **Ricerca e ordinamento base** per azienda o data.
- Apertura di una sessione → **vista dettaglio** con il riepilogo e le domande catturate (riusa la vista debrief del milestone 6).
- **Editing delle domande**: aggiungere, modificare il testo, rimuovere.
- **Invio o ri-invio del recap** via email da una sessione passata.
- **Eliminazione** di una sessione (pulizia).
- I dati **sopravvivono** alla chiusura del browser e sono ritrovabili in qualsiasi momento.

### Cosa il milestone 7 NON include

- Analytics/statistiche sulle sessioni.
- Export CSV/PDF dell'archivio.
- Azioni bulk (selezione multipla).
- Condivisione/permessi tra utenti diversi (c'è un account condiviso).

### Fatto quando

L'operatore apre l'archivio, trova una sessione passata cercandola per azienda/data, la apre, modifica o aggiunge una domanda, ri-invia il recap, e può eliminare una sessione; tutte le modifiche persistono.
