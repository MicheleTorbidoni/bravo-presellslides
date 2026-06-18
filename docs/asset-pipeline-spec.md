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

| Frame Figma | File |
|---|---|
| `C01-step1-MAIN` | `C01-step1.png` |
| `C01-step2-bomN-MAIN` | `C01-step2-bomN.png` |
| `C01-step3.f1-MAIN`, `C01-step3.f2-MAIN` | `C01-step3.f1.png`, `.f2.png` |

---

## 3. Cartelle (content/assets)

- `content/assets/criticalities/C<NN>/` → bitmap **condivise** della criticità (sorgente di verità, sincronizzata da Figma).
- `content/assets/<segmento>/` → **override per segmento** (raro/opzionale).
- Niente più `common/` né `concept`. Una sola copia del condiviso (no duplicazione per segmento).

`<segmento>` ∈ id di `content/config/segments.json`.

---

## 4. Catena di risoluzione (a runtime)

Per (criticità, step, fase, segmento, profilo operativo), dal più specifico:

```
1. token      criticalities/C<NN>/C<NN>-step<Y>-<token>[.f<Z>].png   (se il profilo contiene quel token)
2. segmento   <segmento>/C<NN>-step<Y>[.f<Z>].png                     (override per segmento)
3. condiviso  criticalities/C<NN>/C<NN>-step<Y>[.f<Z>].png            (default)
4. placeholder (nessun file) → placeholder client col nome file
```

Regole:
- **Token singolo**; se più token del profilo combaciassero, vince la decisione più profonda nell'albero. Token non raggiungibili → mai selezionati.
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
- Il sync scarta `-MAIN`, scrive in `content/assets/criticalities/C<NN>/`.
- **Override per segmento**: meccanismo di autoring da definire quando servirà il primo override reale (deferred).
- Esecuzione on-demand via Claude + MCP Figma (dry-run poi export). Nessuno script committato.

---

## 7. Stato e migrazione

- **Figma**: pagine criticità C01–C13 in autoring. Le **pagine-segmento** (Common + 7 segmenti) sono **obsolete** → da rimuovere.
- **Codice (DA FARE)**: `ContentConfig`/controller/`SlidePlayer` file-driven su `criticalities/` + override segmento + token; `slides.json` → testo-per-step; `present_session` deve passare `operational_profile`; `PresentationAssetsController` con la catena §4; rimuovere tipi e `assetIsSegmentVariant`.
- **Asset (DA FARE)**: condivise rigenerate via sync da Figma (si parte dal subset meccanica per la demo). Rimuovere i 105 placeholder vecchi, i `criticality-*` e i 13 `concept`.
