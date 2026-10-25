# Spec: Pipeline dei contenuti visivi (asset delle slide)

Modello di **risoluzione, naming e produzione** dei contenuti del player prospect: bitmap PNG e, da M19, minivideo MP4. Complementare a [`docs/specs.md`](./specs.md). Aggiornato: 2026-10-24 (M19, minivideo negli step).

> ⚠️ **Migrazione in corso.** Modello target = **autoring per criticità** + risoluzione file-driven. Il vecchio schema (`criticality-<n>-<tipo>`, tipi di slide, `concept` in `common/`, cartelle per segmento) è **deprecato**.

---

## 1. Modello concettuale

- L'autoring è **per criticità**: il flusso di slide di una criticità è definito **una volta sola** (in Figma, una pagina per criticità), con le eventuali **varianti per token** del decision tree.
- I **subset per segmento** (quali criticità mostra un segmento) vivono solo nel `.json` (`content/config/mappings.json`). Figma non sa nulla dei segmenti.
- La verticalizzazione per segmento è un **override opzionale**: di default una criticità è condivisa da tutti i segmenti che la includono; un segmento può sovrascrivere una singola slide quando serve.

Una criticità è una **sequenza di step**; ogni step ha un **testo** (titolo/body, overlay del player, da `slides.json`) e uno o più **media di fase** (file-driven): ogni fase è una bitmap `.png` oppure un minivideo `.mp4` (§8). `step1` è l'apertura. Non esistono più i tipi `concept`/`screenshot`/`sequence`.

---

## 2. Convenzione di naming

**Frame Figma:** `C<NN>-step<Y>[-<token>][.f<Z>]-MAIN`
**File su disco:** `C<NN>-step<Y>[-<token>][.f<Z>][.audio].<png|mp4>` (per le PNG = nome frame **senza `-MAIN`**, più `.png`)

- `NN` = criticità a 2 cifre (C03). `Y` = step da 1.
- `<token>` = codice risposta dell'albero, **con trattino** (es. `-bomN`), opzionale.
- `.f<Z>` = fase, **col punto**, opzionale, in coda. Assente ⇒ singola immagine.
- `.audio` = solo sui `.mp4`, **col punto**, ultimo pezzo prima dell'estensione: video **parlato** (§8). Su una `.png` il file viene ignorato.
- Ordine fisso: token → fase → `.audio` → estensione.
- `-MAIN` = residuo di lavorazione, **scartato** dal sync.
- Parsing (`ContentConfig.parse_asset_name`): riconosce l'estensione (`.png` → immagine, `.mp4` → video; ogni altra, `.mov` compreso, ⇒ file ignorato), stacca `.audio`, poi `.f<Z>` (punto), poi split per `-` → `C<NN>`, `step<Y>`, eventuale `<token>`. (Token mai numerico ⇒ niente ambiguità con la fase.)
- ⚠️ **La fase usa il punto `.f<Z>`, mai il trattino `-f<Z>`.** Un `-f1` viene interpretato come *token* (es. `C05-step2-f1.png` → token `f1`, mai selezionabile) e il file diventa morto. Controllare sempre l'export su questo. Lo stesso vale per `.audio`: scritto `-audio` è un token e il video non viene mai mostrato.

| Frame Figma | File |
|---|---|
| `C01-step1-MAIN` | `C01-step1.png` |
| `C01-step2-bomN-MAIN` | `C01-step2-bomN.png` |
| `C01-step3.f1-MAIN`, `C01-step3.f2-MAIN` | `C01-step3.f1.png`, `.f2.png` |
| — (esportato a mano) | `C03-step2.mp4` (video muto), `C03-step2.audio.mp4` (parlato), `C09-step4.f2.mp4` (fase video) |

---

## 3. Cartelle (content/assets)

- `content/assets/criticalities/` → media **condivisi** della criticità (file `C<NN>-step<Y>…png|mp4`, struttura **flat**; le PNG sincronizzate da Figma, i video esportati a mano).
- `content/assets/<segmento>/` → **override per segmento** (raro/opzionale).
- Niente più `common/` né `concept`. Una sola copia del condiviso (no duplicazione per segmento).
- I sorgenti `.mov` possono stare temporaneamente accanto ai `.mp4` per la conversione, ma sono **git-ignorati** (`content/assets/**/*.mov`) e l'app non li vede.

`<segmento>` ∈ id di `content/config/segments.json`.

---

## 4. Catena di risoluzione (a runtime)

Per (criticità, step, fase, segmento, profilo operativo), dal più specifico:

```
1. segmento+token  <segmento>/C<NN>-step<Y>-<token>[.f<Z>].<ext>    (token verticalizzato per segmento)
2. token           criticalities/C<NN>-step<Y>-<token>[.f<Z>].<ext> (token condiviso, se il profilo lo contiene)
3. segmento        <segmento>/C<NN>-step<Y>[.f<Z>].<ext>            (override per segmento)
4. condiviso       criticalities/C<NN>-step<Y>[.f<Z>].<ext>         (default)
5. placeholder     (nessun file) → placeholder client col nome file
```

dove a **ogni anello** `<ext>` si prova nell'ordine `.audio.mp4` → `.mp4` → `.png`: a parità di nome logico vince il video parlato, poi quello muto, poi l'immagine. La catena resta prioritaria sull'estensione (una `.png` del segmento batte un `.mp4` condiviso). (`ContentConfig.resolve_phase` / `media_in`)

Regole:
- **Token**: si itera dai token del profilo dalla decisione più profonda dell'albero verso la radice; **per ciascun token la variante del segmento batte quella condivisa**. La prima che esiste vince. Token non raggiungibili → mai selezionati.
- **Struttura segment-driven**: la sequenza di step e di fasi di una criticità è dedotta dai file **default (senza token)** della cartella del **segmento** (`<segmento>/C<NN>-step<Y>[.f<Z>][.audio].<png|mp4>`; i video contano esattamente come le PNG). Ogni segmento autora il proprio flusso: può avere più/meno step o un diverso numero di fasi rispetto agli altri. La cartella condivisa `criticalities/` è il **fallback**: la sua struttura si usa solo per le criticità che il segmento **non** copre affatto. I file con token non definiscono step nuovi — sovrascrivono solo l'immagine di uno step già esistente. (`ContentConfig.step_structure`)
- **Fasi**: per (step + variante) se esistono `.f1`, `.f2`, … ⇒ N fasi in sequenza (pallini), titolo/body fissi; altrimenti 1 media. Le fasi possono mescolare immagini e video (es. `.f1.png` + `.f2.mp4`). Non mescolare `…stepY.png` con `…stepY.fN.png`.
- **Forma verso il frontend**: ogni fase è `{ url, kind: "image" | "video", audio }`; `url` porta un parametro di versione `?v=<mtime>` (vedi §8).

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

---

## 8. Minivideo (M19)

| File | Comportamento nel player |
|---|---|
| `C03-step2.png` | immagine (invariato) |
| `C03-step2.mp4` | video **muto**, parte da solo, **in loop** finché chi conduce non avanza |
| `C03-step2.audio.mp4` | video **parlato**: parte da solo con l'audio, niente loop, si ferma sull'ultimo frame. Se il browser blocca l'avvio con audio compare un pulsante play che **non** fa avanzare la slide |
| `C03-step2-bomN.mp4` | variante per token (stesse regole delle PNG) |
| `C09-step4.f2.mp4` | fase 2 video di uno step a fasi |

- Il click sul resto della slide e il tasto → avanzano come sempre; cambiando step o fase il video precedente viene smontato (niente audio residuo).
- La fase/step **successivi** vengono precaricati mentre si è su quello corrente.
- Volumi attesi: ~25 video da 1–3 MB, nel repo come le PNG (niente LFS/storage esterno).

**Servizio e cache** (`PresentationAssetsController`): content type per estensione (`image/png`, `video/mp4`), richieste HTTP `Range` supportate (`206 Partial Content`, necessarie a Safari per i video) delegando a `Rack::Files`, `Accept-Ranges: bytes`, `ETag` forte e `Cache-Control: private, max-age=31536000, immutable` per tutti gli asset. Gli URL portano `?v=<mtime>`: un file ri-esportato con lo stesso nome cambia URL e viene riscaricato, altrimenti il browser lo serve dalla cache anche alla call successiva.

**Conversione dei sorgenti** (`bin/convert-minivideo`, richiede `ffmpeg` → `brew install ffmpeg`):

```bash
bin/convert-minivideo content/assets/criticalities/C04-step3.mov        # → C04-step3.mp4 (muto)
bin/convert-minivideo content/assets/criticalities/C04-step3.audio.mov  # → C04-step3.audio.mp4 (con audio)
bin/convert-minivideo -f …   # sovrascrive un .mp4 esistente;  CRF=23 bin/convert-minivideo …  per più qualità
```

H.264 / yuv420p, larghezza massima 1920 px, `+faststart`, CRF 26 di default. La traccia audio viene **rimossa** se il nome non contiene `.audio` (AAC 128k altrimenti). Il `.mov` resta accanto ma è git-ignorato: **non committarlo mai**. I video non passano dal sync Figma.
