# Spec: Pipeline dei contenuti visivi (asset delle slide)

Documento focalizzato sulla **risoluzione, il naming e la produzione** delle bitmap mostrate nel player prospect. Complementare a [`docs/specs.md`](./specs.md) (§3 "Le tre dimensioni di personalizzazione", §6 criticità). Aggiornato: 2026-06-18.

---

## 1. Modello concettuale

La risoluzione di una criticità è una **sequenza di slide**. Ogni slide ha:

- un **testo** (titolo + body) — resta dichiarato in `content/config/slides.json`;
- un **asset base** (una bitmap) — il cui contenuto e il cui *numero di immagini* sono determinati dai **file presenti su disco**, non dichiarati in config.

Tre dimensioni indipendenti modulano *quale* bitmap viene caricata per una slide:

| Dimensione | Origine | Effetto sull'asset |
|---|---|---|
| **Segmento industriale** | scelto in setup | quale variante (cartella) |
| **Token decisionale** | risposta nell'albero | override opzionale della variante |
| **Fase** | conteggio file | 1 immagine statica vs N immagini in sequenza |

> Nota: il **profilo operativo** (foglia dell'albero) determina il *subset di criticità* mostrato nell'hub (vedi `mappings.json`, 126 incroci segmento×profilo, oggi con subset identico per tutte le foglie di un segmento). Le **immagini** dipendono invece da (segmento × token × fase), non dal profilo intero.

---

## 2. Convenzione di naming dei file

```
criticality-<n>-<slide>[.<token>][.f<k>].png
                         │          └ fase numerica (1..N), mostrate in sequenza
                         └ override per token decisionale (codice alfabetico, es. bomN)
```

- `<slide>` ∈ { `concept`, `screenshot`, `step-1`, `step-2`, … } come da `slides.json`.
- **`.<token>`** — codice di una risposta dell'albero (`content/config/decision-tree.json`), es. `.bomN`, `.bom1`, `.mrp`. Alfabetico.
- **`.f<k>`** — indice di fase, numerico. Assente ⇒ singola immagine.

Esempi:

| File | Significato |
|---|---|
| `criticality-1-screenshot.png` | default segmento, 1 immagine |
| `criticality-11-step-2.bomN.png` | override "multilivello", 1 immagine |
| `criticality-11-step-2.f1.png` + `.f2.png` | default, 2 fasi in sequenza |
| `criticality-11-step-2.bomN.f1.png` + `.f2.png` | override "multilivello", 2 fasi |

### Cartelle (dimensione segmento)

- `content/assets/common/` — asset segment-independent (`assetIsSegmentVariant: false`, es. tutti i `concept`).
- `content/assets/<segmento>/` — asset segment-variant (`assetIsSegmentVariant: true`, es. `screenshot`, `step-*`).

`<segmento>` ∈ id di `content/config/segments.json` (meccanica, elettronica, precisione, lamiere-e-metalli, alimentare, imballaggi-e-packaging, gomma-e-plastica).

---

## 3. Catena di risoluzione (a runtime)

Dato (asset base, segmento, profilo operativo), il server sceglie il file dal più specifico al più generico:

```
1. override per token   content/assets/<segmento>/<base>.<token>[.f<k>].png   (token presente nel profilo)
2. default segmento     content/assets/<segmento>/<base>[.f<k>].png
3. default comune       content/assets/common/<base>[.f<k>].png
4. placeholder          (nessun file) → placeholder client con il nome file
```

Regole:
- **Token singolo.** Un asset varia lungo **una sola** dimensione decisionale. Se nel profilo combaciassero più token con override per lo stesso base, vince **la decisione più profonda nell'albero**.
- **Token non raggiungibili.** Override su token che nessun profilo può produrre (es. `bom1`/`bomN` quando si è risposto `nobom`) non vengono mai selezionati → fallback. (Possibile lint che li segnala come "morti".)
- **Fasi.** Raggruppando per base(+token): se esistono `.f1`, `.f2`, … ⇒ N fasi in **sequenza** (avanzo con la freccia, pallini indicatori; titolo/body restano fissi). Altrimenti 1 immagine. Non mescolare `<base>.png` con `<base>.fN.png`.

---

## 4. Produzione contenuti da Figma (workflow)

Naming **umano** in Figma; la traduzione in convenzione la fa il sync.

- **Una pagina Figma per segmento**, nome pagina = label del segmento (→ id via `segments.json`). I `concept` vanno in `common/` (riconosciuti da `slides.json`).
- **Frame top-level** = una bitmap. Il contenuto può essere istanze di componenti riusati: il sync **rasterizza il frame** come PNG piatto.
- Naming dei frame (default + suffissi umani):

| Frame Figma | → file |
|---|---|
| `criticality-11-step-2` | `…step-2.png` |
| `criticality-11-step-2 — Multilivello` | `…step-2.bomN.png` |
| `criticality-11-step-2 — 1`, `— 2` | `…step-2.f1.png`, `.f2.png` |
| `criticality-11-step-2 — Multilivello — 1`, `— 2` | `…step-2.bomN.f1.png`, `.f2.png` |

Regole del sync:
- ultimo segmento **numerico puro** = fase; segmento **alfabetico** = label risposta → token (via `decision-tree.json`). I token non sono mai numeri ⇒ nessuna ambiguità.
- match della label **tollerante**: case-insensitive, spazi ignorati, separatore `—`/`-`/`--`.
- export a **~@2x** (lato lungo ~2680px) per nitidezza fullscreen.

**Esecuzione del sync:** on-demand via Claude + MCP Figma. Prima un **dry-run** (elenco frame riconosciuti, traduzione, scritture pianificate) poi l'export reale. Nessuno script committato per ora.

---

## 5. Stato e piani

**Track A — Contenuti (nessun codice).** Riempire i default mancanti e depositare gli override/fasi.
- `concept` (common): 13/13 ✓
- segment-variant default: `meccanica` 16/16 ✓; gli altri 6 segmenti = **105 mancanti** → coperti dallo *scaffold placeholder* (vedi §6).

**Track B — Backbone di risoluzione (codice, DA FARE).** Necessario perché token e fasi vengano *selezionati* a runtime:
1. passare `operational_profile` alla pagina `present` (oggi `present_session` lo omette) e al player;
2. estendere `PresentationAssetsController` con la catena di fallback (§3);
3. rendere il player **file-driven** sul conteggio fasi (oggi le `sequence` sono dichiarate in `slides.json`); `slides.json` mantiene testi/struttura ma può abbandonare l'array `steps` esplicito;
4. `assetUrl` (`SlidePlayer.tsx`) deve passare segmento + profilo.

Finché il Track B non esiste: i **default** si vedono già; i file `.<token>`/`.f<k>` restano **inerti**.

---

## 6. Scaffold dei placeholder default

Per avere un match **1:1 cartelle ↔ frame Figma**, si materializzano i 105 default mancanti come **placeholder PNG etichettati** (grigio + nome file impresso), senza toccare i file reali esistenti. Quando si sincronizza da Figma, il sync **sovrascrive in place**. Solo default: niente suffissi `.<token>`/`.f<k>`.
