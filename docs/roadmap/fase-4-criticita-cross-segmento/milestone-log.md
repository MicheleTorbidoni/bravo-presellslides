# M14 — Criticità extra da altri segmenti — Milestone log

## Novità nell'app

- Nel **Setup**, sotto la lista "Criticità da discutere", compare un pannello **"Aggiungi criticità da un altro segmento"**: un menù a tendina elenca tutti i segmenti tranne quello del prospect.
- Scelto un segmento alternativo, si vedono **tutte** le sue criticità; il pulsante **"Aggiungi"** è attivo solo per quelle non già presenti nel subset del prospect (le altre mostrano "Già presente") e non ancora aggiunte (mostrano "Aggiunta").
- Una criticità aggiunta appare nella lista principale **come tutte le altre** — casella on/off e trascinamento per l'ordine — con in più un **badge del segmento di origine** (es. "Elettronica") e una **"X"** per rimuoverla.
- L'aggiunta vale **solo per questa call**: viene salvata con l'auto-save (sopravvive ai reload) e **non** modifica il catalogo globale né altre sessioni.
- Cambiare il segmento industriale del prospect **azzera** le criticità extra aggiunte.
- Durante la call la criticità extra compare regolarmente nell'hub del prospect e, quando entra nel flusso, mostra le **slide verticalizzate del segmento di origine**.
- Se la criticità extra viene discussa, compare anche nella pagina di **recap** post-call, con il video di approfondimento risolto sul segmento di origine.

## Cosa è stato costruito

**Modello dati**
- Migration `20260703000001_add_extra_criticalities_to_presale_sessions`: nuova colonna `extra_criticalities` (`jsonb`, default `[]`, `null: false`) su `presale_sessions`. Ogni voce è `{ "id" => Integer, "segment" => String }` (id della criticità + segmento di origine). Nessun serializer custom: l'accesso è come per gli altri campi array/jsonb.

**Backend — `PresaleSessionsController`**
- Nuovi helper privati:
  - `extra_segment_by_id(session)` → mappa `id => segmento di origine` per gli extra.
  - `allowed_ids(session)` = subset del segmento **∪** id extra, in ordine canonico (prima il segmento, poi gli extra non già presenti).
- `effective_selected_ids`: nel ramo *selezione esplicita* il clamp passa da `& segment_ids` a `& allowed_ids(session)` (gli extra nascono selezionati perché "Aggiungi" li mette in `selected_criticalities`); il ramo di default (selezione `nil`) resta sul solo segmento, perché senza selezione esplicita non possono esistere extra.
- `effective_criticalities_order`: ordina/clampa su `allowed_ids` invece che sul solo segmento, così gli extra entrano nella sequenza di presentazione.
- `setup`: nuova prop `extraCriticalities` (`@session.extra_criticalities`).
- `steps_by_criticality`: ogni criticità è risolta contro il **suo** segmento — `extra_by_id[id] || session.segment` — così gli extra usano le slide del segmento di origine; l'`operational_profile` resta quello di sessione.
- `session_params`: permesso `extra_criticalities: [[ :id, :segment ]]`.
- `present` / `result` / `debrief` non modificati: derivano già dagli `effective_*` (e `present` indicizza l'intero catalogo, quindi gli extra risolvono).

**Backend — recap (`PublicRecapsController`)**
- `recap_criticalities` costruisce il subset del segmento e poi **appende gli extra discussi** non già presenti (dedup per id), ognuno con `video_url_for` risolto sul **segmento di origine**. Estratti due helper: `recap_criticality` (shape della singola voce) e `extra_recap_criticalities` (append degli extra discussi). `discussed_criticality_labels` non è cambiato: indicizza già l'intero catalogo, quindi le label degli extra si risolvono da sole.

**Frontend — `Setup.tsx`**
- Nuova prop/stato `extras: { id, segment }[]`, aggiunta ai payload `apiPatch` (effetto debounced **e** `continueToProfiling`) e alle dipendenze dell'effetto.
- `SortableCriticality` esteso con props **opzionali** `sourceSegmentLabel?` e `onRemove?`: presenti solo sulle righe extra (badge origine + "X"); le righe di segmento restano invariate.
- Lista combinata: `byId`/`orderedCriticalities` includono ora gli extra (risolti in `criticalitiesBySegment[extra.segment]`), integrati nel `SortableContext` e in `order`/`selected`.
- Nuovo componente `AddFromSegmentPanel`: `<Select>` dei segmenti (escluso quello del prospect) + elenco delle criticità del segmento scelto con "Aggiungi"/"Già presente"/"Aggiunta".
- `pickSegment` azzera anche gli extra; `addExtra`/`removeExtra` mantengono coerenti `extras`, `selected` e `order`.

**Test**
- `test/controllers/presale_sessions_controller_test.rb`: `setup` espone `extraCriticalities`; l'id fuori-segmento sopravvive se registrato come extra e viene scartato altrimenti (clamp su `allowed_ids`); `present` include l'extra nell'ordine e ne risolve le slide sul segmento di origine; `update` persiste `extra_criticalities`.
- `test/controllers/public_recaps_controller_test.rb`: un extra **discusso** compare nel recap con video sul segmento di origine; un extra non discusso non viene appeso.
- `test/system/setup_extra_criticalities_test.rb` (nuovo): flusso end-to-end nel Setup (aggiunta, badge, "X", persistenza, reset al cambio segmento), rendering a larghezza mobile, e comparsa dell'extra nell'hub con slide del segmento di origine.

## Decisioni non pre-specificate

- **Recap = solo extra discussi.** Coerente col PRD e con `PublicRecap.tsx`, che mette in evidenza le criticità discusse. Gli extra non discussi non vengono appesi (evita di esporre nel recap del prospect criticità mai affrontate).
- **Ordine canonico di `allowed_ids`**: segmento prima, poi gli extra non già nel segmento. Così l'ordine di default (mai riordinato) resta stabile e prevedibile, con gli extra in coda.
- **`effective_selected_ids` default invariato**: il ramo con selezione `nil` continua a clampare sul solo segmento, perché un extra può esistere solo dopo un'azione esplicita "Aggiungi" (che scrive una selezione esplicita).
- **Verifica UI**: la skill `agent-browser` non è disponibile in questo ambiente; la verifica end-to-end è stata fatta con un system test Capybara/headless-Chrome (stessa infrastruttura di `present_flow_test.rb`), mantenuto come coverage permanente. Screenshot (desktop + mobile) in `tmp/screenshots/m14-*.png`.
- **Nota ambiente test**: il build Vite di test va compilato una volta (`RAILS_ENV=test bin/vite build`) prima di lanciare la suite con `VITE_RUBY_AUTO_BUILD=false`, altrimenti build concorrenti producono un manifest parziale (errori `ENOTEMPTY` / "unexpected end of input"). Non è un problema del codice M14.

## Cosa deve sapere il prossimo milestone

- Gli extra vivono **solo** su `PresaleSession#extra_criticalities`; catalogo, `mappings.json` e segmenti restano immutati (nessuno "spostamento" reale tra segmenti).
- `allowed_ids` è ora il punto unico che definisce "quali id può discutere questa sessione" (segmento ∪ extra). Chi aggiunge nuove superfici a valle dovrebbe derivare da `effective_selected_ids` / `effective_criticalities_order` anziché re-implementare `& segment_ids`.
- La risoluzione contenuto degli extra usa il segmento di origine ma l'`operational_profile` della sessione (i token dell'albero sono globali). Se in futuro servisse un profilo specifico per il segmento di origine, andrebbe modellato a parte.

## Deviazioni dal PRD

Nessuna deviazione sostanziale. Il campo libero "oppure?" nella mail HubSpot e il parsing del testo del prospect restano fuori scope come previsto: è Loredana a decidere manualmente cosa aggiungere.
