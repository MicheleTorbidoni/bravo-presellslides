# Milestone 1 — Fondamenta & contenuti — Log

## Novità nell'app

- Dopo il login compare una nuova voce **"Sessioni"** nella barra di navigazione.
- Da lì l'operatore vede l'**elenco delle proprie sessioni di pre-sale** (con nome azienda, data di creazione e stato).
- Un pulsante **"Nuova sessione"** crea una sessione e la mostra subito in lista; la sessione **resta salvata** anche dopo aver chiuso e riaperto il browser.
- Quando non ci sono sessioni viene mostrato uno stato vuoto con invito a crearne una.
- Sotto il cofano sono ora presenti i **contenuti di configurazione** (7 segmenti industriali, 13 criticità, decision tree, mapping, slide d'esempio) che alimenteranno i prossimi milestone. Sono dati placeholder: testi e immagini definitivi arriveranno più avanti.

---

## Cosa è stato costruito

### Contenuti di configurazione (`content/`)
- `content/config/segments.json` — i **7 segmenti** (id slug kebab-case + label). Gli slug sono la fonte canonica per i nomi delle cartelle asset e per la chiave `segment` nei mapping.
- `content/config/criticalities.json` — tutte e **13 le criticità** (id 1–13 + label, da specs §6).
- `content/config/decision-tree.json` — le **5 domande** con i salti condizionali, schema a nodi: `{ start, questions: { <id>: { id, text, answers: [{ label, next|leaf }] } } }`. Le risposte terminali portano `leaf` = profilo operativo (placeholder: `profilo-1`, `profilo-2`, `profilo-b`).
- `content/config/mappings.json` — 5 esempi `{ segment, operationalProfile, criticalities: [int] }`.
- `content/config/slides.json` — slide d'esempio per le criticità 1 e 4, con i tre tipi `concept`, `screenshot`, `sequence` (quest'ultimo con array `steps`). Include esempi di variabili `{{company_name}}` nel body.
- `content/assets/<7 segmenti>/` + `content/assets/common/` — bitmap placeholder PNG 1×1 per gli asset referenziati da `slides.json` (in `meccanica` ed `elettronica` per le varianti segmento; in `common` per i concept). Le cartelle segmento senza asset hanno un `.keep`.

### Loader
- `app/models/content_config.rb` — modulo `ContentConfig` con metodi `.segments`, `.decision_tree`, `.criticalities`, `.mappings`, `.slides`. Legge i JSON con `symbolize_names: true`. **Memoizza in produzione**, rilegge ad ogni chiamata fuori produzione (edit del JSON senza restart). Metodo `.reload!` per i test.

### Modello dati
- Migrazione `db/migrate/20260615000001_create_presale_sessions.rb` → tabella `presale_sessions`: `user_id` (FK), `company_name`, `contact_name`, `segment`, `operational_profile`, `discussed_criticalities` (Postgres `integer[]`, default `[]`, not null), `status` (string, default `"in_progress"`, not null), timestamps.
- `app/models/presale_session.rb` — `belongs_to :user`; `enum :status { in_progress, closed, recap_sent }`; nessuna validazione stringente (deve poter nascere vuota).
- `app/models/user.rb` — aggiunto `has_many :presale_sessions, dependent: :destroy`.

### Route, controller, UI
- `config/routes.rb` — `resources :presale_sessions, only: %i[ index create update ]`.
- `app/controllers/presale_sessions_controller.rb`:
  - `index` → render Inertia `"PresaleSessions/Index"` con le sessioni di `Current.user` (id, company_name, status, created_at iso8601), ordinate per data desc.
  - `create` → `Current.user.presale_sessions.create!` + **redirect** a `presale_sessions_path` (mutazione Inertia → redirect, come da CLAUDE.md).
  - `update` → endpoint **auto-save** chiamato via `fetch` raw: `update!` dei campi permessi + `head :ok`. Strong params: company_name, contact_name, segment, operational_profile, status, `discussed_criticalities: []`. Scoping su `Current.user.presale_sessions.find` (un utente non può toccare le sessioni altrui → 404).
- `app/javascript/pages/PresaleSessions/Index.tsx` — pagina con `AppShell` + design system del template, `<Head>` coi 4 meta, `<h1>` bare, lista sessioni (Badge di stato), stato vuoto, pulsante "Nuova sessione" (`router.post("/presale_sessions")`).
- `app/frontend/components/MainNav.tsx` — aggiunta voce "Sessioni" (icona `ClipboardList`, href `/presale_sessions`) a `DEFAULT_NAV_ITEMS`.

### Test
- `test/models/presale_session_test.rb` — creazione vuota, default status, default `discussed_criticalities = []`, enum, update persiste, `dependent: :destroy`.
- `test/controllers/presale_sessions_controller_test.rb` — redirect a login se non autenticato; index 200; create +1 e redirect; update persiste + 200; un utente non può aggiornare la sessione di un altro (404).
- `test/models/content_config_test.rb` — i file caricano senza eccezioni; 7 segmenti; 13 criticità (id 1–13); start valido nel tree; ogni mapping referenzia segmento e criticità note.
- `test/fixtures/presale_sessions.yml` — una sessione per `users(:one)`.

### Verifica
- `bin/rails db:migrate` ok.
- `bin/rails test` → **38 run, 0 failure** (incluso `ssr_smoke_test`).
- `npm run check` → pulito.
- `bin/rubocop` sui file nuovi → nessuna offesa (stile omakase: spazi dentro le parentesi degli array).
- Smoke dev-env del loader: 7 / 13 / 5 / start `d1` / route risolte.

---

## Decisioni prese (non pre-specificate nel PRD)

- **Naming pagina React**: `PresaleSessions/Index.tsx` invece di `Session/...` (come nell'esempio §11 del PRD) per non confondersi col model `Session` di autenticazione del template. Stessa ragione per il model `PresaleSession`.
- **`segments.json`**: introdotto come fonte unica dei 7 segmenti (non era esplicito nel PRD). Slug canonici: `meccanica`, `elettronica`, `precisione`, `lamiere-e-metalli`, `alimentare`, `imballaggi-e-packaging`, `gomma-e-plastica`.
- **Profili placeholder nel decision tree**: `profilo-1` (distinta semplice), `profilo-2` (multilivello), `profilo-b` (no distinte). Vedi nota sotto per M2.
- **`discussed_criticalities`** modellato come Postgres `integer[]` (default `[]`).
- **Voce di nav** aggiunta a `DEFAULT_NAV_ITEMS` di `MainNav` (anziché passare items custom via `AppShell`), perché le sessioni sono la feature primaria dell'app.

---

## Cosa deve sapere il milestone successivo (M2 — Setup & profilazione)

- **Auto-save**: l'endpoint `PATCH /presale_sessions/:id` esiste già e accetta company_name, contact_name, segment, operational_profile, status, discussed_criticalities. M2 deve **creare la sessione** (POST, esiste) all'avvio del setup e poi chiamare l'`update` via `fetch` raw man mano che l'operatore compila (non via router Inertia, così resta `head :ok`).
- **Config**: usare `ContentConfig.segments` per la griglia dei 7 segmenti (id + label), `ContentConfig.decision_tree` per le 5 domande/salti, `ContentConfig.mappings` per risolvere il subset di criticità (lookup `segment × operationalProfile`), `ContentConfig.criticalities` per le label.
- **Leaf ↔ profilo operativo**: nel decision tree attuale il `leaf` è un id profilo placeholder sulle risposte terminali (3 valori). **Da finalizzare in M2**: definire con precisione come il percorso completo di risposte determina l'`operational_profile` salvato sulla sessione e usato come chiave nei mapping (oggi i mapping usano `profilo-1/2/b`). Se servono profili distinti per percorso, aggiornare sia `decision-tree.json` sia `mappings.json`.
- **Pagina sessioni**: `PresaleSessions/Index.tsx` è volutamente minimale; M6 la espanderà ad archivio completo (ricerca, dettaglio, elimina). M2 aggiungerà le schermate di setup/decision tree come pagine/route separate.

## Note / heads-up per più avanti

- **Serving delle bitmap al browser** (per il player, M4): gli asset stanno sotto `content/assets/` (non in web-root). M4 dovrà decidere come servirli (controller asset dedicato, copia/symlink in `public/`, o pipeline Vite). Per M1 non serve perché non c'è ancora rendering di slide.
- **Tabella domande**: non creata in M1 (la cattura domande è M4). M4 dovrà decidere tra una tabella `questions` relazionale (consigliata, per edit individuale in M5/M6) o una colonna jsonb su `presale_sessions`.
- **Account condiviso/seed**: il login funziona con i seed esistenti (`user@test.com` / `test123`). Nessuna modifica ai seed in M1.

## Scostamenti dal PRD

- Nessuno sostanziale. Le uniche divergenze sono di naming (`PresaleSessions/` vs `Session/`) e l'aggiunta di `segments.json`, entrambe concordate con l'utente in fase di piano.
