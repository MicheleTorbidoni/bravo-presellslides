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
| **Segmento industriale**  | 7 segmenti (vedi §4)                  | Determina il subset di criticità e può sovrascrivere (override) una specifica bitmap rispetto al default condiviso |
| **Profilo operativo**     | Leaf node del decision tree (vedi §5) | Determina il subset di criticità; un suo *token* (es. `bomN`) può selezionare una variante di una specifica slide |
| **Criticità selezionate** | subset per segmento, su 13 totali (vedi §6) | Determina la sequenza di **step** (con eventuali **fasi**) da mostrare |


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

Le criticità sono autorate **una volta sola** (bitmap condivise per criticità); la verticalizzazione per segmento è un **override opzionale** — un segmento sovrascrive una specifica bitmap solo quando serve davvero (vedi §8 e `asset-pipeline-spec.md`). Le bitmap sono **statiche** (PNG), incluse nel progetto come asset.

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

Ogni combinazione (segmento industriale × profilo operativo) produce un subset di criticità rilevanti, definito in `content/config/mappings.json` (non nel codice). La risoluzione è `ContentConfig.criticalities_for(segment:, operational_profile:)`: lookup sulla **coppia** (segmento, profilo); se la coppia non è mappata → fallback alla lista completa delle 13.

**Stato attuale (implementato):** `mappings.json` materializza **tutti i 126 incroci** = 7 segmenti × 18 foglie dell'albero. Oggi il subset **dipende dal segmento** (lo stesso subset è replicato su tutte le 18 foglie di quel segmento), ma essendo righe separate per profilo resta **raffinabile per modalità operativa** in futuro editando il singolo incrocio. L'helper `ContentConfig.operational_profiles` enumera le 18 foglie.

```json
{
  "mappings": [
    { "segment": "meccanica", "operationalProfile": "ho-excel-bom-bom1", "criticalities": [1, 2, 3, 4, 7, 8, 10] },
    ...
  ]
}

```

I subset per segmento attuali: meccanica `[1,2,3,4,7,8,10]`, elettronica `[3,7,8,9,11,13]`, precisione `[1,2,3,4,6,7,8]`, lamiere-e-metalli `[1,2,3,4,11,12]`, alimentare `[2,4,7,9,11,12]`, imballaggi-e-packaging `[1,2,3,4,6,5,7]`, gomma-e-plastica `[1,2,4,5,7,11,12]`.

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

**Hub criticità** (pagina `Present`, vista `hub`)

- Titolo: *"Dove fa più difficoltà la tua azienda?"*
- Le criticità del subset pre-calcolato appaiono come **pillole cliccabili**
- **Cliccare una pillola avvia subito il flusso** di quella criticità (nessun pulsante "Avvia" separato — con 4-5 criticità per set stanno tutte nell'hub). Le criticità già discusse appaiono come tali e sono ri-entrabili.

**Flusso slide per criticità** (vista `flow`, il player)

- Una criticità è una sequenza ordinata di **step**; ogni step ha un titolo/body (overlay) e **1..N fasi** (bitmap mostrate in sequenza, con pallini indicatori). Struttura e numero di immagini sono **file-driven** (vedi §8), non un numero fisso.
- Navigazione: → / click avanza (fase → step → completa), ← indietro. Completato il flusso si torna all'hub e la criticità è segnata come **discussa** (persistito).
- Ogni step può contenere: testo (titolo/body con `{{company_name}}` / `{{contact_name}}`) e le bitmap di fase (risolte per segmento/token).

**Cattura domande del prospect (durante la presentazione):**

- Si attiva **solo tramite scorciatoia da tastiera `Q`** (nessun pulsante a schermo, per non sporcare la vista condivisa)
- `Q` → overlay minimale con campo di testo libero
- Conferma → domanda **salvata nella sessione (persistita, auto-save)**, overlay si chiude
- Le domande sono associate allo **step corrente** (`slide_id` = es. `C01-step2`) e alla criticità (per contesto nel debrief)
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
    slides.json               # testi (titolo/body) per step, per criticità
  /assets
    /criticalities            # bitmap condivise per criticità (flat)
      C01-step1.png
      C01-step2.png
      C01-step2-bomN.png      # variante per token decisionale
      C01-step3.f1.png        # step con più fasi (sequenza)
      C01-step3.f2.png
      C02-step1.png
      ...
    /<segmento>               # override per segmento (raro/opzionale)
      C01-step2.png

```

### Schema slide (slides.json)

> Il modello completo (naming, fasi, override per token, risoluzione, workflow Figma) è in [`docs/asset-pipeline-spec.md`](./asset-pipeline-spec.md). Qui solo l'essenziale.

`slides.json` contiene **solo i testi** (titolo/body) per **step**, per criticità. La struttura e il **numero di immagini sono file-driven** (dedotti dai file `C<NN>-step<Y>[.token][.fZ].png` su disco), non dichiarati qui.

```json
{
  "criticalities": [
    {
      "id": 1,
      "label": "Tempi di produzione non raccolti",
      "steps": [
        { "title": "Tempi disponibili da subito.", "body": "Ogni fase di {{company_name}} viene tracciata senza sforzo." },
        { "title": "Come si costruisce il ciclo.", "body": null }
      ]
    }
  ]
}

```

**Step e fasi.** La risoluzione di una criticità è una sequenza di **step** (ognuno col suo titolo/body, overlay del player). Uno step può avere più **fasi** (`.f1`, `.f2`, …): più bitmap mostrate in sequenza (avanzo con la freccia, pallini indicatori) mantenendo fisso titolo/body. `step1` è l'apertura. Non esistono più i tipi `concept`/`screenshot`/`sequence`.

**Organizzazione e override.** L'autoring è **per criticità**: le bitmap condivise stanno in `content/assets/criticalities/` (flat, `C<NN>-step…png`) e valgono per tutti i segmenti che includono la criticità. La **verticalizzazione per segmento** è un override opzionale in `content/assets/<segmento>/`. Un'immagine può avere un **override per token decisionale** (es. `-bomN`). Catena di risoluzione: **token → segmento → condiviso → placeholder** (dettagli in `asset-pipeline-spec.md`).

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

Shortcut globali (da qualunque vista): `C` → pagina di chiusura, `S` → esci all'archivio sessioni, `F` / `F11` → toggle fullscreen.
Solo nel flow:

- Freccia destra / click → avanza (fase successiva → step successivo → completa il flusso)
- Freccia sinistra → indietro (fase/step precedente)
- `Q` → apre overlay cattura domanda

Quando uno step ha più fasi, i **pallini indicatori** in basso mostrano la fase corrente.

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
| Asset storage | File statici in `content/assets/` (fuori dal web root), serviti da `PresentationAssetsController` | Se gli asset crescono: migrare a S3/Cloudflare R2 |


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

Implementazione reale: `PresaleSessionsController` (azioni `index`, `setup`, `profiling`, `result`, `present`, `update`). I contenuti statici sono letti via `ContentConfig` (cache in produzione, re-read in dev). Esempio essenziale:

```ruby
# PresaleSessionsController
def setup
  render inertia: "PresaleSessions/Setup",      # fase 1: prospect + segmento
         props: { session: ..., segments: ContentConfig.segments }
end

def profiling
  render inertia: "PresaleSessions/Profiling",  # fase 1: decision tree (walk client-side)
         props: { session: ..., tree: ContentConfig.decision_tree }
end

def present
  render inertia: "Present", props: {           # fase 2: hub + player + chiusura
    session: ..., criticalities: ..., prefiltered: ...,
    discussedCriticalities: ...,
    stepsByCriticality: steps_by_criticality(@session), # step/fasi risolti per segmento+profilo
    capturedQuestions: ...
  }
end

# update = sink di auto-save (raw fetch, head :ok — NON via Inertia router)
# Le bitmap sono servite da PresentationAssetsController
#   GET /presentation_assets/:dir/:filename  (:dir = "criticalities" | segment id)
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
- [x] **Numero di slide per criticità:** **Non fisso** — la struttura (numero di step e di fasi) è **file-driven**, dedotta dai bitmap `C<NN>-step<Y>[.f<Z>].png` in `content/assets/criticalities/`. Uno step può avere più fasi (mini-animazione) — vedi §8 e `asset-pipeline-spec.md`.
- [ ] **Hosting credenziali:** Chi gestisce l'account di hosting e le variabili d'ambiente (API key email, JWT secret)?
- [x] **Accesso Figma per token:** I valori esatti di colore e font sono da estrarre dal file Figma. Rimandato: lo si farà più avanti, prima della rifinitura delle slide.

---

## 14. Stato di implementazione

Sintesi di cosa è costruito (al 2026-06-18), per orientare gli sviluppi futuri. Il dettaglio del modello asset è in [`asset-pipeline-spec.md`](./asset-pipeline-spec.md).

**Costruito e testato**
- **Auth + schermate interne** (login, setup, profiling, result) con design system del template.
- **Sessione persistita + auto-save** (`PresaleSession`): azienda, contatto, segmento, profilo operativo, criticità discusse, **domande catturate** (colonna `jsonb`), stato. Auto-save via raw `fetch` su `PATCH update` (`head :ok`, non Inertia).
- **Profilazione**: `decision-tree.json` percorso client-side (`Profiling.tsx`); profilo = foglia (codici uniti da `-`).
- **Subset criticità**: `mappings.json` con **126 incroci** (7×18); `ContentConfig.criticalities_for`.
- **Superficie prospect** (`Present.tsx`, autonoma, niente design system): hub → flow (player) → chiusura, stato vista effimero; shortcut `C`/`S`/`F`/`Q`; cattura domande legate allo step.
- **Pipeline asset file-driven per criticità**: bitmap `C<NN>-step<Y>[-<token>][.f<Z>].png` in `content/assets/criticalities/`; struttura step/fasi dedotta dai file; risoluzione **token > segmento (override) > condiviso > placeholder** (`ContentConfig.steps_for`); rotta `presentation_assets/:dir/:filename` + `PresentationAssetsController`. `slides.json` = testo-per-step.
- **Workflow Figma → repo**: autoring **per criticità** (pagine C01–C13), sync on-demand via MCP (vedi `asset-pipeline-spec.md`).

**Da completare / fuori da ciò che è stato costruito finora**
- **Arte reale delle bitmap**: oggi `criticalities/` contiene **placeholder** etichettati; vanno ri-esportati con i contenuti veri (stessi nomi → sovrascrittura).
- **Testi per-step** in `slides.json`: carry-over dai vecchi titoli dove possibile, altrimenti `null` (da autorare).
- **Debrief / recap email / archivio avanzato** (§7 Fase 3): esiste solo l'`index` base; debrief, editing domande, invio recap via Resend **non** ancora implementati.
- **Pulizia pagine-segmento Figma** obsolete; **override per segmento** (meccanismo di autoring); **mini-video** (embed remoto). Tutti deferred.

---

## 15. Riferimenti

- **Figma file:** `https://www.figma.com/design/9DFvljjqtdEtJgOzCPrpNq/01--Funnel--Pre-sale-Meeting--1a-?node-id=1-26`
- **Brand:** Bravo Manufacturing (prodotto di Antos SRL)
- **Utente primario:** Loredana, team pre-sale Antos SRL

