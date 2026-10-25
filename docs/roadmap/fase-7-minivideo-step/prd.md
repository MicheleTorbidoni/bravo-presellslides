# Bravo Manufacturing Pre-Sale Tool — Fase 7: Minivideo negli step

> **Informazioni su questi file di roadmap:** questa cartella (`docs/roadmap/fase-7-minivideo-step/`) contiene il PRD e il prompt della **Fase 7** dell'app, un incremento costruito **sopra** i milestone già rilasciati (fino a M18, Fase 6). Come le fasi precedenti è un artefatto di guida: nessun codice, configurazione o logica di runtime deve importare o dipendere da questi file. La fonte di verità è il codice.

## Cosa stiamo costruendo

Durante la call, chi conduce spiega ogni criticità appoggiandosi agli **step** della presentazione. Oggi ogni step (o fase di step) è esclusivamente una bitmap PNG. Vogliamo poter usare anche dei **minivideo**: brevi clip (schermate animate, demo) che partono da sole appena lo step compare.

I minivideo seguono **esattamente lo stesso modello file-driven delle PNG**: sono file `.mp4` in `content/assets/`, nella stessa cartella e con la stessa grammatica dei nomi. Il contenuto resta verticalizzabile per segmento, gli override per token funzionano, e `criticalities/` fa da riserva. Per l'autore dei contenuti l'unica differenza è l'estensione del file, più un suffisso `.audio` per i pochi video parlati.

La maggior parte dei video è **muta** e va in **loop**. Alcuni sono **parlati**: partono con l'audio e si fermano sull'ultimo frame. L'audio del browser verso la call è già instradato con Loopback (macOS), quindi l'app non deve occuparsi della cattura audio.

Volumi previsti: **al massimo ~25 video**, da 1–3 MB l'uno dopo la conversione. Stanno nel repo come le PNG: niente Git LFS, niente storage esterno.

La Fase 7 è costruita in **un solo milestone** (M19).

---

### Cosa fa l'app (novità della Fase 7)

- Uno step, o una singola fase di uno step, può essere un **minivideo** invece di un'immagine. Le fasi miste sono ammesse, ad esempio `.f1` immagine e `.f2` video.
- I minivideo **muti** partono da soli e vanno in loop finché chi conduce non avanza.
- I minivideo **parlati** (suffisso `.audio`) partono da soli con l'audio e si fermano sull'ultimo frame. Se il browser blocca l'avvio con audio, compare un pulsante per avviarli o attivare l'audio.
- Lo step successivo viene **precaricato** mentre si è ancora su quello corrente, così il video parte senza attese.
- Immagini e video restano in **cache nel browser**: alla call successiva, con lo stesso segmento, partono all'istante. Se un file viene ri-esportato con lo stesso nome, il browser scarica la versione nuova.
- Titolo, testo, logo e indicatori di fase restano invariati, come per le slide immagine.

---

### Grammatica dei nomi file (estensione di quella esistente)

```
C<NN>-step<Y>[-<token>][.f<Z>][.audio].<png|mp4>
```

| File | Comportamento |
|---|---|
| `C03-step2.png` | immagine (invariato) |
| `C03-step2.mp4` | video muto, autoplay, loop |
| `C03-step2.audio.mp4` | video con audio, autoplay, stop sull'ultimo frame |
| `C03-step2-bomN.mp4` | variante per token (stesse regole di risoluzione delle PNG) |
| `C09-step4.f2.mp4` | fase 2 video di uno step a fasi |

Regole:
- `.audio` ha senso solo sui `.mp4` ed è **l'ultimo pezzo prima dell'estensione**, col punto come le fasi. Scritto `-audio` col trattino verrebbe letto come token e il file non sarebbe mai mostrato.
- Ordine fisso: token → fase → `.audio` → estensione.
- A parità di nome logico vince **`.audio.mp4` > `.mp4` > `.png`**.
- I file video **contano per la struttura** (numero di step e di fasi) esattamente come le PNG di default (senza token).
- I `.mov` sorgente **non** sono riconosciuti dall'app e **non** vanno committati: vengono convertiti in `.mp4` (vedi sotto).

---

### Già fornito dal codice esistente (da riusare, non ri-specificare)

- **`ContentConfig`** (`app/models/content_config.rb`):
  - `parse_asset_name` oggi usa `File.basename(file, ".png")` e scarta di fatto ogni file non PNG. Va esteso a `.mp4` e `.audio`.
  - `structure_in_dir` / `step_structure` gestiscono la struttura segment-driven con fallback `criticalities/`. La logica resta la stessa, cambia solo l'insieme dei file riconosciuti.
  - `resolve_phase_url` segue la catena `segmento+token → token condiviso → segmento → condiviso`. Va esteso per provare, a ogni anello, le estensioni nell'ordine di priorità.
  - `intro_steps` usa la stessa struttura: deve continuare a funzionare. I video nell'intro sono ammessi gratis se la grammatica è condivisa, ma non sono un requisito.
  - `asset_exists?` / `asset_url` sono i punti in cui aggiungere il parametro di versione (`?v=<mtime>`).
- **`PresentationAssetsController`**: oggi `send_file … type: "image/png"` fisso e nessun header di cache. Va servito il content type corretto in base all'estensione, va verificato il supporto alle richieste HTTP Range (Safari lo richiede per i video, ed è utile per l'avvio rapido) e va aggiunto un `Cache-Control` lungo.
- **`app/frontend/components/present/SlidePlayer.tsx`**:
  - `Step.phases: string[]`, dove ogni fase è un URL. `SlideImage` renderizza la fase corrente con placeholder su errore.
  - Lo step video **finale** di M18 (`VideoSlide`, embed YouTube/Vimeo da `videos.json`) è una cosa **diversa** e resta invariato. Attenzione a non confondere i nomi: il nuovo componente per i minivideo inline va chiamato diversamente (es. `SlideVideo` / `StepMedia`).
- **`Present.tsx`**: `advancePosition`/`backPosition` leggono solo `.phases.length`. Se la forma delle fasi cambia, il conteggio non deve cambiare.
- **Lezione da M18** (vedi `docs/roadmap/fase-6-migliorie-flusso/milestones/18-video-finale-criticita/milestone-log.md`): l'autoplay **non muto** di un `<iframe>` YouTube appena montato falliva. Per un `<video>` nativo nella stessa pagina, il gesto utente recente (click o → per avanzare) di norma basta, ma non è garantito. Per questo serve il fallback con pulsante sui video `.audio`.

---

### Fuori scope (Fase 7)

- **Link YouTube/Vimeo come step**: valutati e scartati come strada principale (interfaccia di YouTube visibile, dipendenza dalla rete, nessuna integrazione con la verticalizzazione file-driven). Il video finale di M18 resta l'unico punto in cui si usano gli embed.
- **Git LFS o storage esterno** (S3/R2): non serve con ~25 video. Da rivalutare se il volume cresce molto.
- **Streaming adattivo** (HLS/DASH): basta il download progressivo per clip brevi.
- **Controlli del player** (seek bar, volume, velocità) e **analytics di visione**.
- **Sync Figma → video**: i minivideo vengono esportati a mano, non tramite il sync MCP delle bitmap.
- **Verticalizzazione per segmento dei contenuti**: oggi tutte le cartelle dei segmenti sono vuote e tutto arriva da `criticalities/`. Il meccanismo resta supportato, ma popolarlo è content authoring.

---

### Modello dati

Nessuna nuova tabella o colonna, nessuna nuova config JSON. Tutto è file-driven da `content/assets/`. `slides.json` resta invariato: titoli e testi per step, nessun flag video.

---

## Milestone M19 — Minivideo come step o fase di step

### Cosa viene costruito

- **Grammatica estesa** in `ContentConfig`: riconoscimento di `.mp4` e del suffisso `.audio`, inclusione dei video nella struttura step/fasi, priorità `.audio.mp4 > .mp4 > .png` a ogni anello della catena di risoluzione.
- **Forma delle fasi arricchita** verso il frontend: ogni fase deve dire almeno **URL**, **tipo** (immagine/video) e **audio sì/no**. La forma esatta (oggetto per fase, oppure deduzione dall'URL) si decide in fase di plan. Vanno aggiornati coerentemente steps delle criticità, intro, tipi TS e test esistenti.
- **Servizio dei file** (`PresentationAssetsController`): content type per estensione (`image/png`, `video/mp4`), supporto Range verificato con un test (risposta `206` a una richiesta `Range:`), `Cache-Control` lungo (es. `public, max-age=31536000, immutable`) **insieme** a un parametro di versione nell'URL (`?v=<mtime>` generato da `asset_url`), così un file ri-esportato con lo stesso nome viene riscaricato. Vale per tutti gli asset, PNG comprese.
- **Player** (`SlidePlayer.tsx`): nuovo componente per la fase video con `<video autoPlay playsInline preload="auto">`.
  - Muto (default): `muted loop`.
  - `.audio`: con audio, senza `loop`, fermo sull'ultimo frame. Se `play()` viene rifiutato, mostrare un pulsante play/"attiva audio" che non faccia scattare l'avanzamento (`stopPropagation`, come la facade di M18).
  - Il click sul resto dello stage e il tasto → avanzano come su ogni slide.
  - Cambiando step o fase il video precedente si ferma, senza audio residuo.
  - Placeholder su errore di caricamento, riusando `MissingPlaceholder`.
- **Precaricamento** della fase/step successivi (immagine o video) mentre si è su quello corrente.
- **Conversione dei sorgenti**: uno script (es. `bin/convert-minivideo`) che prende un `.mov` e produce l'`.mp4` con lo stesso nome logico in H.264, `+faststart`, risoluzione e bitrate adatti al web. Se il nome **non** contiene `.audio`, la traccia audio va rimossa. Richiede `ffmpeg` (oggi non installato: lo script deve dirlo chiaramente). In più una regola `.gitignore` per i `*.mov` sotto `content/assets/`.
- **Contenuti di prova**: conversione di `content/assets/criticalities/C04-step3.mov` (19 MB, l'unico video reale oggi) in `C04-step3.mp4`. Gli 11 `.mp4` segnaposto già presenti restano dove sono e diventano visibili.
- **Test**: parsing dei nomi (estensioni, `.audio`, `-audio` col trattino ignorato come token, fasi miste), priorità a parità di nome, struttura con video, controller (content type, Range, cache, 404, path traversal invariato), system test della navigazione con step e fase video, e attributi `muted`/`loop` corretti per muto e parlato. Le criticità di prova restano fittizie (C97/C98/C99), come nei test esistenti. **Screenshot** desktop + mobile in `tmp/screenshots/`.

### Cosa il milestone M19 esplicitamente NON include

- Embed YouTube/Vimeo come step (il video finale di M18 resta com'è).
- Controlli del player oltre al pulsante di fallback per l'audio.
- Storage esterno, LFS, streaming adattivo.
- Modifiche a `slides.json`, `videos.json`, `mappings.json`.

### Done when

- In una sessione reale, gli step con un `.mp4` in `criticalities/` (es. C02-step3, C04-step3, C10-step1) mostrano il video che parte da solo, muto e in loop.
- Un file `.audio.mp4` di prova parte con l'audio e si ferma sull'ultimo frame. Se l'autoplay con audio viene bloccato, compare il pulsante.
- Una fase video dentro uno step a fasi (es. C09-step4.f2) funziona, con gli indicatori di fase corretti.
- La navigazione (click, →, indietro) funziona come prima e non resta audio quando si cambia slide.
- Una seconda visita allo stesso step non riscarica il file (verificato dagli header di risposta), mentre un file ri-esportato con lo stesso nome viene riscaricato.
- `bin/rails test` e `bin/rails test:system` passano al 100%, e `npm run check` e `bin/rubocop` sono puliti.
