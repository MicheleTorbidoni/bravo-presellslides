# Spec: Pipeline dei contenuti visivi (asset delle slide)

Documento focalizzato sulla **risoluzione, il naming e la produzione** delle bitmap mostrate nel player prospect. Complementare a [`docs/specs.md`](./specs.md) (§3 "Le tre dimensioni di personalizzazione", §6 criticità). Aggiornato: 2026-06-18.

> ⚠️ **Migrazione in corso** alla nomenclatura `C<NN>-step<Y>`. Questo documento descrive il **modello target**. Lo stato di avanzamento è in §6. Il vecchio schema (`criticality-<n>-<concept|screenshot|step>`, tipi di slide, `concept` in `common/`) è **deprecato**.

---

## 1. Modello concettuale

La risoluzione di una criticità è una **sequenza di step**. Ogni step ha:

- un **testo** (titolo + body) — overlay HTML del player, dichiarato in `content/config/slides.json`;
- una o più **bitmap di fase** — il cui *numero* è determinato dai **file presenti su disco** (file-driven), non dichiarato in config.

Non esistono più i "tipi" di slide (`concept`/`screenshot`/`sequence`): tutto è uno **step**, eventualmente suddiviso in **fasi**. Lo `step1` è l'apertura (quella che prima era lo `screenshot`). **Non c'è più un `concept`** segment-independent.

Tre dimensioni indipendenti modulano *quale* bitmap viene caricata:

| Dimensione | Origine | Effetto sull'asset |
|---|---|---|
| **Segmento industriale** | scelto in setup | quale cartella (`content/assets/<segmento>/`) |
| **Token decisionale** | risposta nell'albero | override opzionale dell'immagine |
| **Fase** | conteggio file | 1 immagine statica vs N immagini in sequenza |

> Nota: il **profilo operativo** (foglia dell'albero) determina il *subset di criticità* mostrato nell'hub (vedi `mappings.json`, 126 incroci segmento×profilo). Le **immagini** dipendono da (segmento × token × fase), non dal profilo intero.

### 1.1 Step e fasi

- **Step** = un momento della narrazione (apertura, dettaglio, "come funziona"…). Ha il suo titolo/body. Avanzando con la freccia si passa allo step successivo.
- **Fase** = una bitmap dentro lo stesso step. Se uno step ha più fasi, vengono mostrate **in sequenza** (avanzo con la freccia, pallini indicatori), mantenendo **fisso** titolo/body dello step.

La suddivisione di una criticità in step e fasi è una **scelta editoriale**, autorata in Figma (vedi §5) e scoperta dal codice via file.

---

## 2. Convenzione di naming dei file

```
C<NN>-step<Y>[.<token>][.f<Z>].png
 │     │       │          └ fase numerica (1..N), opzionale, sempre in coda
 │     │       └ override per token decisionale (alfabetico, es. bomN), opzionale
 │     └ indice di step (da 1). step1 = apertura
 └ criticità a 2 cifre (Criticità 3 → C03)
```

- **`<token>`** — codice di una risposta dell'albero (`content/config/decision-tree.json`), es. `bomN`, `bom1`, `mrp`. Alfabetico, **prima** della fase.
- **`.f<Z>`** — indice di fase, numerico, **in coda**. Assente ⇒ singola immagine. Regola: "trailing numerico = fase" → nessuna ambiguità con il token (mai numerico).

Esempi:

| File | Significato |
|---|---|
| `C03-step1.png` | criticità 3, step 1, 1 immagine |
| `C11-step3.png` | criticità 11, step 3, 1 immagine |
| `C11-step3.f1.png` + `.f2.png` | step 3 con 2 fasi in sequenza |
| `C11-step3.bomN.png` | step 3, override "multilivello", 1 immagine |
| `C11-step3.bomN.f1.png` + `.f2.png` | step 3, override "multilivello", 2 fasi |

### Cartelle (dimensione segmento)

- `content/assets/<segmento>/` — **tutti** gli asset (sono tutti segment-variant).
- `content/assets/common/` — tier di fallback **latente** nella catena (vedi §4), oggi non popolato (il `concept` comune è stato eliminato).

`<segmento>` ∈ id di `content/config/segments.json` (meccanica, elettronica, precisione, lamiere-e-metalli, alimentare, imballaggi-e-packaging, gomma-e-plastica).

### Mini-video (futuro)

Quando uno step sarà un mini-video (embed remoto, es. YouTube), servirà un indicatore dedicato nella grammatica. Fuori scope ora.

---

## 3. Testi degli step (`slides.json`)

`content/config/slides.json` conserva **solo i testi**, per criticità e per step:

```json
{ "id": 1, "label": "Tempi di produzione non raccolti",
  "steps": [ { "title": "…", "body": "…" }, { "title": "…", "body": null }, … ] }
```

L'ordine degli step nell'array = step1, step2, …. Il **numero di immagini** non è qui: è scoperto dai file. `{{company_name}}` / `{{contact_name}}` restano interpolati a runtime.

---

## 4. Catena di risoluzione (a runtime)

Dato (criticità, step, fase, segmento, profilo operativo), il server sceglie il file dal più specifico al più generico:

```
1. override per token   content/assets/<segmento>/C<NN>-step<Y>.<token>[.f<Z>].png   (token nel profilo)
2. default segmento     content/assets/<segmento>/C<NN>-step<Y>[.f<Z>].png
3. default comune       content/assets/common/C<NN>-step<Y>[.f<Z>].png   (latente)
4. placeholder          (nessun file) → placeholder client con il nome file
```

Regole:
- **Token singolo.** Un asset varia lungo **una sola** dimensione decisionale. Se più token del profilo combaciassero per lo stesso step, vince **la decisione più profonda nell'albero**.
- **Token non raggiungibili.** Override su token che nessun profilo può produrre (es. `bom1`/`bomN` con risposta `nobom`) non vengono mai selezionati → fallback. (Possibile lint che li segnala "morti".)
- **Fasi.** Per (step + token): se esistono `.f1`, `.f2`, … ⇒ N fasi in sequenza; altrimenti 1 immagine. Non mescolare `C<NN>-step<Y>.png` con `C<NN>-step<Y>.fN.png`.

---

## 5. Produzione contenuti da Figma (workflow)

Naming **umano** in Figma; la traduzione in convenzione la fa il sync.

- **Una pagina Figma per segmento**, nome pagina = label del segmento (→ id via `segments.json`).
- **Frame top-level** = una bitmap (= una fase, o uno step a singola fase). Il contenuto può essere istanze di componenti riusati: il sync **rasterizza il frame** come PNG piatto.
- Naming dei frame:

| Frame Figma | → file |
|---|---|
| `C11-step3` | `C11-step3.png` |
| `C11-step3.f1`, `C11-step3.f2` | `C11-step3.f1.png`, `.f2.png` |
| `C11-step3 — Multilivello` | `C11-step3.bomN.png` |
| `C11-step3 — Multilivello — 1`, `— 2` | `C11-step3.bomN.f1.png`, `.f2.png` |

Regole del sync:
- la `.f<Z>` può essere scritta direttamente nel nome frame, oppure come **suffisso numerico umano** (`— 1`) → ultimo segmento numerico puro = fase.
- segmento **alfabetico** appeso = label risposta → token (via `decision-tree.json`). I token non sono mai numeri ⇒ nessuna ambiguità.
- match della label **tollerante**: case-insensitive, spazi ignorati, separatore `—`/`-`/`--`.
- export a **~@2x** (lato lungo ~2680px) per nitidezza fullscreen.

**Esecuzione del sync:** on-demand via Claude + MCP Figma. Prima un **dry-run** (frame riconosciuti, traduzione, scritture pianificate), poi l'export reale. Nessuno script committato per ora.

---

## 6. Stato e migrazione

Migrazione dal vecchio schema (`criticality-<n>-<tipo>`, tipi slide, `concept` in `common/`) al nuovo (`C<NN>-step<Y>`):

- **Figma**: pagina **Elettronica** già autorata in nuova grammatica ✓. Restano: Meccanica + 5 segmenti (precisione, lamiere-e-metalli, alimentare, imballaggi-e-packaging, gomma-e-plastica). Common: vuota (niente concept).
- **Codice (DA FARE)**: rendere `ContentConfig`/controller/player **file-driven** sui nomi `C<NN>-step<Y>[.token][.fZ]`; rimuovere i tipi `concept/screenshot/sequence` e `assetIsSegmentVariant`; ristrutturare `slides.json` a testo-per-step; estendere `PresentationAssetsController` con la catena §4.
- **Asset (DA FARE)**: rigenerati via sync da Figma. I file col vecchio nome (`criticality-*`), i 105 placeholder vecchi e i 13 `concept` in `common/` diventano **obsoleti** e vanno rimossi.

Sequenziamento per non rompere la demo (oggi solo `meccanica` è demo-ready): autorare/sincronizzare meccanica nella nuova grammatica **prima** di rimuovere i suoi asset vecchi.
