# Milestone 2 — Setup & profilazione interna — Log

## Novità nell'app

- Da **"Nuova sessione"** ora parte un **flusso guidato**, non più una riga vuota in lista.
- **Schermata Setup**: l'operatore inserisce *nome azienda* e *nome contatto* del prospect e sceglie il **segmento industriale** da una griglia di 7 card.
- **Decision tree**: 5 domande **una alla volta**, con i **salti automatici** (se la produzione è "Human Only" si salta la domanda sull'IoT; se non gestiscono distinte base si salta il tipo di distinta) e un pulsante **Indietro** per correggere.
- **Schermata risultato**: mostra il **profilo operativo** come percorso leggibile (domanda → risposta) e l'elenco delle **criticità rilevanti**; se la combinazione segmento × profilo non è mappata, compare un **avviso** (le criticità si sceglieranno più avanti).
- I dati del prospect si **salvano automaticamente** mentre si compila: una sessione può essere **ripresa** cliccandola nella lista.

---

## Cosa è stato costruito

### Contenuto (profilo composito)
- `content/config/decision-tree.json` — ristrutturato: ogni risposta ha un `code` (token), il nodo terminale è l'assenza di `next` (rimosso `leaf`). Codici: d1 `ho`/`mixed` · d2 `iot`/`noiot` · d3 `excel`/`mrp` · d4 `bom`(→d5)/`nobom` · d5 `bom1`/`bomN`.
- `content/config/mappings.json` — esempi riscritti con chiavi composite (`operationalProfile` = codici joinati con `-`, es. `ho-excel-bom-bom1`, `mixed-iot-mrp-bom-bomN`).

### Backend
- `app/models/content_config.rb` — due metodi nuovi:
  - `criticalities_for(segment:, operational_profile:)` → subset di criticità `{id,label}` dal mapping, o `[]` (fallback).
  - `decode_profile(operational_profile)` → cammina l'albero dai token e restituisce `[{question, answer}]` leggibile.
- `config/routes.rb` — member GET su `presale_sessions`: `setup`, `profiling`, `result`.
- `app/controllers/presale_sessions_controller.rb` — `create` ora redirige a `setup_presale_session_path`; aggiunte `setup` / `profiling` / `result` (con `before_action :set_session` scoping su `Current.user`); `update` (auto-save) invariata; helper `session_detail` + `segmentLabel` su result.

### Frontend
- `app/frontend/lib/api.ts` (nuovo) — `apiPatch(url, data)`: auto-save via `fetch` raw con token CSRF da `meta[name="csrf-token"]`; legge `document` solo a runtime (SSR-safe). **Riusabile in M4** per la cattura domande.
- `app/javascript/pages/PresaleSessions/`:
  - `Setup.tsx` (nuovo) — campi azienda/contatto + griglia 7 segmenti; auto-save debounced (400ms); "Avanti" → profiling (guard: segmento obbligatorio).
  - `Profiling.tsx` (nuovo) — traversata client-side dell'albero, una domanda alla volta, stack per Avanti/Indietro; al termine salva `operational_profile = codes.join("-")` e va a result.
  - `Result.tsx` (nuovo) — percorso profilo decodificato + criticità rilevanti, o avviso fallback; "Avvia presentazione" disabilitato (M3).
  - `Index.tsx` (modifica) — le righe sono link che riprendono la sessione (`/setup`).

### Test
- `test/models/content_config_test.rb` — `criticalities_for` (match noto → subset atteso; ignoto/nil → `[]`); `decode_profile` (percorso completo, percorso con salto, blank → `[]`).
- `test/controllers/presale_sessions_controller_test.rb` — `create` redirige a setup; setup/profiling/result rendono per l'owner; auth required; result con profilo mappato; scoping 404.

### Verifica
- `bin/rails test` → **47 run, 0 failure** (incluso `ssr_smoke_test`).
- `npm run check` → pulito · `bin/rubocop` → pulito.
- La correttezza di risoluzione/decodifica è nei test unitari di `ContentConfig` (Minitest non ha gli helper Inertia per le props — solo RSpec).

---

## Decisioni prese (non pre-specificate nel PRD)

- **Profilo operativo = composito sul percorso completo** (scelta dell'utente): codici per-risposta nell'albero, profilo = `code.join("-")`. Decodifica leggibile via `decode_profile`. I salti condizionali restano impliciti nei `next` (nessuna logica speciale).
- **Encoding decodificabile**: ogni risposta ha un `code` (anche d4=`bom`), così la decodifica è un walk pulito di un token per domanda.
- **Fallback senza pre-selezione**: se nessun mapping, `criticalities_for` → `[]` e la UI mostra un avviso.
- **3 pagine separate** (setup/profiling/result) via member GET, con traversata dell'albero client-side e persistenza via l'auto-save esistente (config lookups lato server in `result`).
- **`segmentLabel`** passato a result per mostrare il segmento leggibile (non lo slug).

---

## Cosa deve sapere il milestone successivo (M3 — Hub criticità & loop)

- **Risoluzione criticità già pronta**: `ContentConfig.criticalities_for(segment:, operational_profile:)` restituisce il subset (o `[]`). L'hub M3 ("Dove fa più difficoltà") deve partire da questo subset come pillole pre-risolte; il fallback `[]` significa "scelta libera tra le 13" (usare `ContentConfig.criticalities`).
- **Contesto UI custom**: da M3 le schermate sono mostrate al prospect → componenti React **autonomi**, niente import dal design system del template (le pagine M2 invece lo usano, sono interne).
- **Selezione effettiva → `discussed_criticalities`**: M2 NON la popola. M3 dovrà persistere le criticità selezionate/discusse sulla sessione (colonna `discussed_criticalities` già esistente, `integer[]`), via l'auto-save (`apiPatch` / endpoint `update`, che già accetta `discussed_criticalities: []`).
- **Punto di aggancio**: in `Result.tsx` il pulsante "Avvia presentazione" è disabilitato con nota "(M3)" — è lì che l'hub si innesterà; oggi `result_presale_session_path` è la fine del flusso M2.
- **Auto-save pattern**: usare `@/lib/api` `apiPatch` (CSRF + SSR-safe), non il router Inertia, per gli aggiornamenti di stato che non devono cambiare pagina.

## Note / heads-up

- **Copertura mapping**: `mappings.json` ha solo pochi esempi compositi; le combinazioni non coperte cadono nel fallback. La compilazione completa (fino a 18 profili × 7 segmenti) è lavoro di **contenuto**, non di codice, e non blocca M3.
- **Serving bitmap** (per il player M4): ancora aperto — gli asset stanno sotto `content/assets/` (non web-root).
- **Tabella domande**: ancora da decidere in M4 (relazionale vs jsonb).

## Scostamenti dal PRD

- Nessuno sostanziale. Il PRD §11 mostrava azioni `setup`/`profiling`/`present`/`debrief` su un `SessionsController`: qui sono member action di `PresaleSessionsController` (per non confondersi col `Session` di auth) e `present` non è di M2. Allineato nello spirito.
