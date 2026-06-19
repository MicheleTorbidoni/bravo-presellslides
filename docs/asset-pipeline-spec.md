# Spec: Pipeline dei contenuti visivi (asset delle slide)

Modello di **risoluzione, naming e produzione** delle bitmap del player prospect. Complementare a [`docs/specs.md`](./specs.md). Aggiornato: 2026-06-18.

> ⚠️ **Migrazione in corso.** Modello target = **autoring per criticità** + risoluzione file-driven. Il vecchio schema (`criticality-<n>-<tipo>`, tipi di slide, `concept` in `common/`, cartelle per segmento) è **deprecato**.

---

## 1. Modello concettuale

- L'autoring è **per criticità**: il flusso di slide di una criticità è definito **una volta sola** (in Figma, una pagina per criticità), con le eventuali **varianti per token** del decision tree.
- I **subset per segmento** (quali criticità mostra un segmento) vivono solo nel `.json` (`content/config/mappings.json`). Figma non sa nulla dei segmenti.
- La verticalizzazione per segmento è un **override opzionale**: di default una criticità è condivisa da tutti i segmenti che la includono; un segmento può sovrascrivere una singola slide quando serve.

Una criticità è una **sequenza di step**; ogni step ha un **testo** (titolo/body, overlay del player, da `slides.json`) e una o più **bitmap di fase** (file-driven). `step1` è l'apertura. Non esistono più i tipi `concept`/`screenshot`/`sequence`.

---

## 2. Convenzione di naming

**Frame Figma:** `C<NN>-step<Y>[-<token>][.f<Z>]-MAIN`
**File su disco:** `C<NN>-step<Y>[-<token>][.f<Z>].png` (= nome frame **senza `-MAIN`**, più `.png`)

- `NN` = criticità a 2 cifre (C03). `Y` = step da 1.
- `<token>` = codice risposta dell'albero, **con trattino** (es. `-bomN`), opzionale.
- `.f<Z>` = fase, **col punto**, opzionale, in coda. Assente ⇒ singola immagine.
- `-MAIN` = residuo di lavorazione, **scartato** dal sync.
- Parsing: stacca `.f<Z>` (punto), poi split per `-` → `C<NN>`, `step<Y>`, eventuale `<token>`. (Token mai numerico ⇒ niente ambiguità con la fase.)
- ⚠️ **La fase usa il punto `.f<Z>`, mai il trattino `-f<Z>`.** Un `-f1` viene interpretato come *token* (es. `C05-step2-f1.png` → token `f1`, mai selezionabile) e il file diventa morto. Controllare sempre l'export su questo.

| Frame Figma | File |
|---|---|
| `C01-step1-MAIN` | `C01-step1.png` |
| `C01-step2-bomN-MAIN` | `C01-step2-bomN.png` |
| `C01-step3.f1-MAIN`, `C01-step3.f2-MAIN` | `C01-step3.f1.png`, `.f2.png` |

---

## 3. Cartelle (content/assets)

- `content/assets/criticalities/` → bitmap **condivise** della criticità (file `C<NN>-step<Y>…png`, struttura **flat**; sincronizzate da Figma).
- `content/assets/<segmento>/` → **override per segmento** (raro/opzionale).
- Niente più `common/` né `concept`. Una sola copia del condiviso (no duplicazione per segmento).

`<segmento>` ∈ id di `content/config/segments.json`.

---

## 4. Catena di risoluzione (a runtime)

Per (criticità, step, fase, segmento, profilo operativo), dal più specifico:

```
1. segmento+token  <segmento>/C<NN>-step<Y>-<token>[.f<Z>].png    (token verticalizzato per segmento)
2. token           criticalities/C<NN>-step<Y>-<token>[.f<Z>].png (token condiviso, se il profilo lo contiene)
3. segmento        <segmento>/C<NN>-step<Y>[.f<Z>].png            (override per segmento)
4. condiviso       criticalities/C<NN>-step<Y>[.f<Z>].png         (default)
5. placeholder     (nessun file) → placeholder client col nome file
```

Regole:
- **Token**: si itera dai token del profilo dalla decisione più profonda dell'albero verso la radice; **per ciascun token la variante del segmento batte quella condivisa**. La prima che esiste vince. Token non raggiungibili → mai selezionati.
- **Struttura segment-driven**: la sequenza di step e di fasi di una criticità è dedotta dai file **default (senza token)** della cartella del **segmento** (`<segmento>/C<NN>-step<Y>[.f<Z>].png`). Ogni segmento autora il proprio flusso: può avere più/meno step o un diverso numero di fasi rispetto agli altri. La cartella condivisa `criticalities/` è il **fallback**: la sua struttura si usa solo per le criticità che il segmento **non** copre affatto. I file con token non definiscono step nuovi — sovrascrivono solo l'immagine di uno step già esistente. (`ContentConfig.step_structure`)
- **Fasi**: per (step + variante) se esistono `.f1`, `.f2`, … ⇒ N fasi in sequenza (pallini), titolo/body fissi; altrimenti 1 immagine. Non mescolare `…stepY.png` con `…stepY.fN.png`.

---

## 5. Testi degli step (`slides.json`)

Solo testi, per criticità e step:

```json
{ "id": 1, "label": "Tempi di produzione non raccolti",
  "steps": [ { "title": "…", "body": "…" }, { "title": "…", "body": null } ] }
```

Ordine = step1, step2, …. `{{company_name}}`/`{{contact_name}}` interpolati a runtime. Il numero di immagini non è qui (file-driven).

---

## 6. Produzione da Figma (workflow)

- **Una pagina per criticità** (C01–C13). Frame top-level = una bitmap. Contenuto = istanze di componenti riusati; il sync **rasterizza** il frame a PNG piatto @2x (~2680px lato lungo).
- Varianti per token = frame `C<NN>-step<Y>-<token>-MAIN` (label umana ammessa, tradotta in token via `decision-tree.json`; match tollerante).
- Il sync scarta `-MAIN`, scrive in `content/assets/criticalities/` (flat).
- **Verticalizzazione per segmento** (implementato lato codice): lo screenshot dentro la slide è un **component set** (`screenshot/C<NN>-step<Y>`) con proprietà variante `Segmento`. La slide è autorata una volta e contiene un'**istanza** di quel componente; per verticalizzare si imposta la variante di segmento sull'istanza e si esporta un frame per ogni `(segmento, step)` che serve davvero (gli altri ricadono sul condiviso, niente export obbligatorio per tutti e 7).
  - **Routing del file**: l'export deve depositare il PNG in `content/assets/<segmento>/` con lo **stesso filename** del default (`C<NN>-step<Y>[-<token>][.f<Z>].png`); `<segmento>` = id esatto di `segments.json` (con trattini). È solo il path su disco che il runtime legge. Serve quindi una convenzione di nome frame che codifichi il segmento (es. pagina-per-segmento, oppure suffisso `…@<segmento>-MAIN`) così il sync sa in quale cartella scrivere; senza segmento → `criticalities/`.
- Esecuzione on-demand via Claude + MCP Figma (dry-run poi export). Nessuno script committato.

---

## 7. Stato e migrazione

- **Figma**: pagine criticità C01–C13 in autoring. Le **pagine-segmento** (Common + 7 segmenti) sono **obsolete** → da rimuovere.
- **Codice (DA FARE)**: `ContentConfig`/controller/`SlidePlayer` file-driven su `criticalities/` + override segmento + token; `slides.json` → testo-per-step; `present_session` deve passare `operational_profile`; `PresentationAssetsController` con la catena §4; rimuovere tipi e `assetIsSegmentVariant`.
- **Asset (DA FARE)**: condivise rigenerate via sync da Figma (si parte dal subset meccanica per la demo). Rimuovere i 105 placeholder vecchi, i `criticality-*` e i 13 `concept`.
