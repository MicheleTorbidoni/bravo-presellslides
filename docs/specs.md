# Specifiche Applicazione: Bravo Manufacturing Pre-Sale Tool

## 1. Panoramica del Progetto

**Nome applicazione:** Bravo Manufacturing Pre-Sale Tool  
**Tipologia:** Applicazione web browser-based, uso interno  
**Utente principale:** Team pre-sale di Antos SRL (operatore: Loredana)  
**Scopo:** Guidare l'operatore pre-sale attraverso una call conoscitiva con un cliente prospect, presentando slide personalizzate in base al segmento industriale e al profilo operativo del prospect.

**Motivazione rispetto a PowerPoint/Keynote:** L'elemento differenziante è la capacità di riutilizzare un unico set di flussi (le "criticità") e verticalizzare dinamicamente i contenuti visivi (screenshot e grafiche) in base al segmento industriale del prospect. Questo è impossibile o molto oneroso da fare con strumenti di presentazione tradizionali.

---

## 2. Contesto Operativo

- L'operatore conduce la call via streaming (es. Zoom, Meet) e gestisce la condivisione schermo tramite **OBS Studio**
- L'app non ha bisogno di una "presenter view" separata: è OBS che decide quando mostrare l'app al prospect
- Le schermate interne (profilazione) vengono completate **prima** di avviare la condivisione schermo
- Le slide di presentazione devono essere visualizzabili in **modalità fullscreen** o con chrome del browser ridotto al minimo
- Il look & feel deve essere fedele ai mockup Figma del brand Bravo Manufacturing (file: `01--Funnel--Pre-sale-Meeting--1a-`, node `1-26`)

---

## 3. Le Tre Dimensioni di Personalizzazione

L'app combina tre variabili per costruire la sessione:


| Dimensione                | Valori possibili                      | Effetto                                                       |
| ------------------------- | ------------------------------------- | ------------------------------------------------------------- |
| **Segmento industriale**  | 7 segmenti (vedi §4)                  | Determina quale variante di screenshot/grafica viene caricata |
| **Profilo operativo**     | Leaf node del decision tree (vedi §5) | Determina il subset di criticità rilevanti                    |
| **Criticità selezionate** | 4-5 su 13 totali (vedi §6)            | Determina la sequenza di slide da mostrare                    |


---

## 4. Segmenti Industriali

I 7 segmenti coprono in modo sufficientemente preciso l'universo di prospect:

1. Meccanica
2. Elettronica
3. Precisione
4. Lamiere e Metalli
5. Alimentare
6. Imballaggi e Packaging
7. Gomma e Plastica

Per ogni segmento esiste una variante specifica di ogni asset visivo (screenshot del software, grafiche infografiche). Queste varianti sono **bitmap statiche** (PNG/JPG), pre-prodotte e incluse nel progetto come asset.

---

## 5. Decision Tree — Profilazione Operativa

Il decision tree è una sequenza di domande che determina il "profilo operativo" del prospect. Queste schermate **NON vengono mostrate al prospect** (banner visivo di reminder per l'operatore).

### Le domande

L'albero è composto da 5 domande. **Non tutte le domande sono agganciate a tutte le risposte:** alcune vengono saltate in base alla risposta precedente.

| #  | Domanda                          | Risposte possibili                       |
| -- | -------------------------------- | ---------------------------------------- |
| D1 | La produzione è Human Only?      | SI / NO                                   |
| D2 | Avete macchine IoT?              | SI / NO                                   |
| D3 | La produzione è gestita con...   | Excel o carta / MRP (o ERP)              |
| D4 | Gestite le Distinte Base?        | SI / NO                                   |
| D5 | Che tipo di Distinta?            | Semplice (1 livello) / Multilivello      |

**Regole di salto condizionale:**

- **D2 viene posta solo se D1 = NO.** Se D1 = SI (produzione interamente umana), D2 ("Avete macchine IoT?") viene saltata e si passa direttamente a D3.
- **D5 viene posta solo se D4 = SI.** Se D4 = NO (non gestiscono distinte base), D5 ("Che tipo di distinta?") viene saltata e si arriva direttamente al profilo finale.

### Struttura dell'albero

```
[START]
│
├─ D1. La produzione è Human Only?
│   ├─ SI ─────────────────────────► (salta D2) ──► D3
│   └─ NO ─► D2. Avete macchine IoT?
│             ├─ SI ──────────────► D3
│             └─ NO ──────────────► D3
│
├─ D3. La produzione è gestita con...?
│   ├─ Excel o carta ─────────────► D4
│   └─ MRP (o ERP) ───────────────► D4
│
└─ D4. Gestite le Distinte Base?
    ├─ SI ─► D5. Che tipo di Distinta?
    │         ├─ Semplice (1 livello) ──► [PROFILO FINALE]
    │         └─ Multilivello ──────────► [PROFILO FINALE]
    └─ NO ────────────(salta D5)───────► [PROFILO FINALE]

```

Il **profilo operativo** del prospect è identificato dal **leaf node** raggiunto, ossia dal percorso completo di risposte date. Questo identificatore è la chiave (`operationalProfile`) usata in `mappings.json` per determinare il subset di criticità rilevanti (insieme al segmento industriale).

> **Nota per lo sviluppo:** L'albero deve essere configurabile tramite file JSON/YAML, non hardcodato nel codice. La struttura deve permettere di aggiungere nuovi rami in futuro senza modificare il codice applicativo.

### UI del Decision Tree

- Sfondo viola/bordeaux (colore brand interno)
- Domanda in testo grande, bianco, centrata
- Risposte come grandi pulsanti bianchi con testo viola
- Banner rosso fisso in basso: **"NON MOSTRARE AL PROSPECT"**
- Navigazione: avanti alla risposta, possibilità di tornare indietro

---

## 6. Le 13 Criticità

Elenco completo delle criticità identificate:

1. Tempi di produzione non raccolti
2. Costi reali di produzione sconosciuti
3. Date di consegna inaffidabili
4. Fermi macchina non previsti ma costosi
5. Manutenzione solo reattiva
6. Setup e attrezzaggi non ottimizzati
7. Poca/nessuna visibilità della direzione sulla produzione
8. Produzione scollegata dal gestionale aziendale
9. Segniamo ancora tutto su fogli Excel o carta
10. Se manca una persona chiave, siamo fermi
11. Distinte base generiche e non realistiche
12. Scarti e rilavorazioni non analizzati
13. Difficoltà a gestire le varianti in maniera strutturata

### Mapping criticità → profilo

Ogni combinazione (segmento industriale × profilo operativo) produce un subset di 4-5 criticità rilevanti. Questo mapping è definito in un file di configurazione esterno (JSON), non nel codice.

**Struttura del file di configurazione:**

```json
{
  "mappings": [
    {
      "segment": "meccanica",
      "operationalProfile": "1",
      "criticalities": [1, 3, 4, 7, 12]
    },
    ...
  ]
}

```

---

## 7. Flusso di Sessione Completo

### Fase 1 — Setup pre-sessione (non mostrata al prospect)

**Schermata di ingresso:**

- Campo: Nome azienda prospect
- Campo: Nome contatto prospect
- Questi dati vengono iniettati come variabili nelle slide (`{{company_name}}`, `{{contact_name}}`)

**Profilazione:**

1. Selezione segmento industriale (griglia o lista dei 7 segmenti)
2. Navigazione del decision tree (domande sequenziali)
3. Il sistema calcola: profilo operativo → subset di criticità rilevanti

### Fase 2 — Slide di presentazione (mostrata al prospect via OBS)

**Prima slide: Selezione criticità**

- Titolo: *"Dove fa più difficoltà la tua azienda?"*
- Le criticità rilevanti pre-calcolate appaiono come **pillole/tag cliccabili** (verde quando selezionata)
- L'operatore può cliccare per selezionare/deselezionare criticità in tempo reale durante la conversazione
- Un pulsante "Avvia presentazione" / "Continua" procede con le criticità selezionate

**Flusso slide per criticità:**

- Per ogni criticità selezionata: sequenza lineare di slide (N slide per criticità, da definire nel content)
- Navigazione: pulsanti avanti/indietro, possibilità di saltare a criticità successive
- Ogni slide può contenere:
  - Testo fisso (titolo, corpo)
  - Asset visivo variante per segmento (screenshot o grafica infografica — **bitmap**)
  - Variabili personalizzate (`{{company_name}}`, `{{contact_name}}`)

**Cattura domande del prospect (durante la presentazione):**

- Si attiva **solo tramite scorciatoia da tastiera `Q`** (nessun pulsante a schermo, per non sporcare la vista condivisa)
- `Q` → overlay minimale con campo di testo libero
- Conferma → domanda **salvata nella sessione (persistita, auto-save)**, overlay si chiude
- Le domande sono associate all'indice di slide/criticità corrente (per contesto nel debrief)
- L'edit/cancellazione delle domande **non** avviene durante la presentazione, ma più tardi nel debrief/archivio

### Fase 3 — Debrief (post-sessione)

**Schermata debrief:**

- Raggiungibile a fine call (dalla pagina di chiusura) **e anche più tardi dall'archivio sessioni** (è lo stesso record persistito)
- Riepilogo della sessione:
  - Azienda e contatto
  - Segmento industriale e profilo operativo identificato
  - Criticità discusse (elenco)
  - Domande catturate durante la presentazione (con riferimento alla slide/criticità)
- **Editing delle domande** dal debrief: aggiungere, modificare il testo, rimuovere (opera sullo stesso record della sessione)
- Pulsante: **"Invia recap via email"** → apre modale con campo destinatario (pre-compilato o vuoto), corpo del recap in testo editabile prima dell'invio. Invio one-shot via **Resend**; dopo l'invio lo stato della sessione diventa "recap inviato"
- **Future feature (out of scope per MVP):** integrazione HubSpot per salvare il recap nella scheda del prospect

**Archivio sessioni:**

- Schermata interna che elenca le sessioni per azienda/contatto/data, con segmento/profilo e stato (in corso / chiusa / recap inviato)
- Ricerca e ordinamento base per azienda o data
- Apertura di una sessione → vista dettaglio (riusa il debrief) con domande editabili
- Invio o **ri-invio** del recap via email da una sessione passata
- Eliminazione di una sessione (pulizia)

---

## 8. Modello dei Contenuti

### Struttura delle cartelle asset

```
/content
  /config
    decision-tree.json        # struttura dell'albero decisionale
    criticalities.json        # elenco delle 13 criticità con metadati
    mappings.json             # segment × profile → criticality IDs
    slides.json               # struttura delle slide per criticità
  /assets
    /meccanica
      criticality-1-slide-1.png
      criticality-1-slide-2.png
      criticality-4-slide-1.png
      ...
    /elettronica
      ...
    /[altri segmenti]
      ...
    /common
      criticality-1-concept.png
      ...

```

### Schema slide (slides.json)

```json
{
  "criticalities": [
    {
      "id": 1,
      "label": "Tempi di produzione non raccolti",
      "slides": [
        {
          "id": "crit1-slide1",
          "type": "concept",
          "title": "Un ciclo assistito e fluido.",
          "body": null,
          "asset": "criticality-1-concept.png",
          "assetIsSegmentVariant": false
        },
        {
          "id": "crit1-slide2",
          "type": "screenshot",
          "title": "Tempi disponibili da subito.",
          "body": null,
          "asset": "criticality-1-screenshot.png",
          "assetIsSegmentVariant": true
        },
        {
          "id": "crit1-slide3",
          "type": "sequence",
          "title": "Come si costruisce il ciclo.",
          "body": null,
          "steps": [
            { "asset": "criticality-1-step-1.png", "assetIsSegmentVariant": true },
            { "asset": "criticality-1-step-2.png", "assetIsSegmentVariant": true },
            { "asset": "criticality-1-step-3.png", "assetIsSegmentVariant": true }
          ]
        }
      ]
    }
  ]
}

```

**Numero di slide:** ogni criticità ha tra **5 e 8 slide**.

**Slide a sequenza (`type: "sequence"`).** Alcune slide non sono statiche ma una **sequenza ordinata di bitmap/step** che crea una mini-animazione (build progressivo). In questo caso la slide usa il campo `steps` (array) invece del singolo `asset`. La navigazione "avanti" avanza di **uno step alla volta** all'interno della slide; raggiunto l'ultimo step, l'avanti successivo passa alla slide seguente. La navigazione "indietro" funziona in modo speculare. Ogni step può avere il proprio `assetIsSegmentVariant`. Le slide statiche continuano a usare il campo `asset` come prima.

Quando `assetIsSegmentVariant: true`, l'app carica l'asset dalla cartella del segmento selezionato. Quando `false`, carica l'asset dalla cartella `/common`.

---

## 9. Requisiti UI/UX

### Stile visivo

- **Riferimento:** Mockup Figma file `01--Funnel--Pre-sale-Meeting--1a-` (node 1-26)
- **Colori principali (brand Bravo Manufacturing):**
  - Verde: colore dominante delle slide di presentazione
  - Arancio/Giallo: elementi di highlight e icone
  - Viola/Bordeaux: schermate interne (decision tree)
  - Bianco: sfondo card, testo su sfondi scuri
  - Grigio chiaro: sfondo slide tipo "overview"
- **Logo:** Bravo Manufacturing visibile nelle slide di presentazione (in basso a sinistra)
- I valori esatti di colore e font sono da estrarre dal file Figma

### Modalità fullscreen

- L'app deve supportare la modalità fullscreen nativa del browser (Fullscreen API)
- Pulsante nell'UI per attivare/disattivare il fullscreen
- In fullscreen le slide occupano l'intera viewport senza scrollbar né chrome del browser

### Slide layout

- Aspect ratio: 16:9
- Le slide si adattano alla viewport mantenendo il ratio (letterbox se necessario)
- Le bitmap si ridimensionano proporzionalmente all'interno della slide

### Navigazione keyboard

- Freccia destra / click → slide successiva
- Freccia sinistra → slide precedente
- `F` o `F11` → toggle fullscreen
- `Q` → apre overlay cattura domanda

---

## 10. Requisiti Tecnici

### Deployment

- Cloud-hosted (es. Vercel, Railway, Netlify)
- Accesso interno: autenticazione richiesta (non pubblica)
- HTTPS obbligatorio

### Autenticazione

- Login con email + password
- Registrazione autonoma, reset password via email e cambio password sono **mantenuti così come forniti dal template** (zero lavoro custom). La pagina di signup pubblica resta attiva (protetta da rate-limit)
- Sessione persistente (JWT con scadenza configurabile via variabile d'ambiente)
- **Deciso:** MVP con **account condiviso** singolo per il team pre-sale. Tenere l'architettura aperta a un'utenza multipla futura (più utenti individuali) senza riscritture sostanziali.

### Invio email

- Il recap debrief deve essere inviabile via email
- Usare un servizio transazionale (es. **Resend**, SendGrid, o Nodemailer con SMTP)
- Il corpo dell'email è testo strutturato (HTML template semplice)

### Configurazione contenuti

- Tutti i mapping e la struttura dei contenuti sono definiti in **file JSON** nella cartella `/content/config`
- Gli asset sono file statici nella cartella `/content/assets`
- Non è richiesto un pannello di amministrazione per l'MVP
- Per aggiungere un nuovo segmento o modificare i mapping: aggiornare i JSON e fare re-deploy

---

## 11. Stack Tecnologico

### Punto di partenza: template esistente

Usare come base il template `github.com/MicheleTorbidoni/bm-build-new`, già noto al team. Non partire da zero.


| Layer         | Tecnologia                                     | Note                                                              |
| ------------- | ---------------------------------------------- | ----------------------------------------------------------------- |
| Backend       | **Rails 8** (Ruby 3.3.6)                       | Già configurato nel template                                      |
| Frontend      | **React 19** via **Inertia.js**                | No API layer separato: i controller Rails rendono pagine Inertia  |
| Styling       | **Tailwind CSS v4**                            | Già wired up via `@tailwindcss/vite`                              |
| Database      | **PostgreSQL**                                 | Condiviso da Active Record, Solid Queue, Solid Cache, Solid Cable |
| Auth          | `authentication.rb` concern (già nel template) | `require_authentication` già implementato                         |
| Build         | **Vite 7**, Propshaft                          | Già configurato                                                   |
| Email         | Aggiungere **Resend** o SMTP via Action Mailer | Il template ha Solid Queue per background jobs                    |
| Asset storage | Static files in `public/assets/` (MVP)         | Se gli asset crescono: migrare a S3/Cloudflare R2                 |


### Separazione critica dei contesti UI

> ⚠️ **Regola fondamentale per Claude Code:** il design system del template (token, primitive, componenti sotto `components/ui/` e `components/design-system/`) si applica **solo alle schermate interne**. Le slide di presentazione sono un contesto UI separato e autonomo.


| Area dell'app                                     | Stile da usare                                                     |
| ------------------------------------------------- | ------------------------------------------------------------------ |
| Login                                             | Design system del template                                         |
| Setup sessione (nome azienda, segmento)           | Design system del template                                         |
| Decision tree                                     | CSS custom fedele ai mockup Figma (sfondo viola, pulsanti bianchi) |
| Slide di presentazione                            | CSS custom fedele ai mockup Figma (verde, arancio, brand BM)       |
| Schermata criticità ("Dove fa più difficoltà...") | CSS custom fedele ai mockup Figma                                  |
| Debrief e invio email                             | Design system del template                                         |


Le slide sono componenti React autonomi in `app/javascript/pages/slides/` (o simile) che non importano nulla dal design system del template. I loro stili sono definiti da classi Tailwind custom o CSS modules basati esclusivamente sui token Figma di Bravo Manufacturing.

### Pattern Inertia consigliato per le fasi di sessione

```ruby
# SessionsController
def setup
  render inertia: "Session/Setup"           # fase 1: nome prospect + segmento
end

def profiling
  render inertia: "Session/DecisionTree",   # fase 1: decision tree
         props: { tree: decision_tree_config }
end

def present
  render inertia: "Session/SlidePresenter", # fase 2: slide player
         props: { slides: @slides, segment: @segment }
end

def debrief
  render inertia: "Session/Debrief",        # fase 3: recap + email
         props: { session: @session_data }
end

# Archivio sessioni (storico persistito)
def index
  render inertia: "Session/Archive",        # lista sessioni per azienda/data
         props: { sessions: @sessions }
end

```

### Stato di sessione e persistenza

> ⚠️ **Decisione rivista rispetto alle prime bozze:** la sessione **non è più usa-e-getta**. Gli output durevoli della call vengono **persistiti a database**, mentre resta effimera solo l'esperienza di presentazione.

Due livelli distinti:

- **Persistito a DB — model `PresaleSession`** (con **auto-save**: il record si crea all'avvio della sessione e si aggiorna man mano, così nulla va perso anche se il browser viene chiuso). Contiene: nome azienda, nome contatto, segmento, profilo operativo (leaf node), criticità discusse, **elenco domande catturate** (testo + riferimento slide/criticità + ora), data/creazione, stato (in corso / chiusa / recap inviato). Ogni sessione appartiene all'utente loggato.
- **Effimero — React state lato client (Context o Zustand)**: solo lo stato di runtime della presentazione (slide/step corrente, fullscreen, selezioni temporanee delle pillole prima del consolidamento). Si ricostruisce ad ogni apertura, non viene salvato.

Su questo record persistito poggia l'**archivio sessioni** (vedi §7, Fase 3): elenco, dettaglio/debrief, editing domande, invio/ri-invio recap, eliminazione.

---

## 12. Fuori Scope (MVP)

Le seguenti funzionalità sono note ma escluse dall'MVP:

- Integrazione HubSpot (salvataggio recap nel CRM)
- Pannello di amministrazione per la gestione dei contenuti
- Analytics sulle sessioni (quali segmenti più frequenti, criticità più discusse)
- Multi-lingua
- Registrazione/replay della sessione
- Modalità offline
- Account individuali / ruoli / multi-utenza (per ora un solo account condiviso; architettura tenuta aperta)
- Ottimizzazione mobile/touch (è uno strumento desktop guidato via OBS)
- UI di upload asset / storage su S3-R2 (le bitmap sono file statici nel repo)
- Editor visuale del decision tree, dei mapping o delle slide (si editano i file JSON a mano)
- Sul recap: destinatari multipli / CC, tracking aperture-click, invii programmati, allegati, editor HTML ricco

> **Nota:** la **persistenza delle sessioni e l'archivio** (in forma minimale) **sono ora in scope** per l'MVP — vedi §7 Fase 3 e §11. Resta fuori solo l'integrazione HubSpot, che in futuro assorbirà lo storage degli outcome.

---

## 13. Domande Aperte

- [x] **Autenticazione:** MVP con **account condiviso** singolo per il team pre-sale. L'architettura deve restare aperta a un'**utenza multipla** in futuro senza riscritture sostanziali.
- [x] **Email mittente:** Per l'MVP `loredana.mosca@antos.it`. Deve essere **configurabile** (variabile d'ambiente) in vista di un cambio futuro.
- [x] **Destinatario email recap:** Il **prospect**. Nell'MVP l'indirizzo viene inserito manualmente dall'operatore; in futuro probabilmente arriverà da HubSpot.
- [x] **Numero di slide per criticità:** Tra **5 e 8 slide** per criticità. Alcune slide non sono statiche ma una **sequenza di step/bitmap** (mini-animazione) — vedi schema slide in §8.
- [ ] **Hosting credenziali:** Chi gestisce l'account di hosting e le variabili d'ambiente (API key email, JWT secret)?
- [x] **Accesso Figma per token:** I valori esatti di colore e font sono da estrarre dal file Figma. Rimandato: lo si farà più avanti, prima della rifinitura delle slide.

---

## 14. Riferimenti

- **Figma file:** `https://www.figma.com/design/9DFvljjqtdEtJgOzCPrpNq/01--Funnel--Pre-sale-Meeting--1a-?node-id=1-26`
- **Brand:** Bravo Manufacturing (prodotto di Antos SRL)
- **Utente primario:** Loredana, team pre-sale Antos SRL

