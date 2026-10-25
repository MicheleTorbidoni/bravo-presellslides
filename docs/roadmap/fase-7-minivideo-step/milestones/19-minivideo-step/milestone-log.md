# Milestone 19 — Log

## Novità nell'app

- Uno step della presentazione, o una singola fase di uno step, può ora essere un **minivideo** invece di un'immagine. Basta mettere un file `.mp4` in `content/assets/` con lo stesso nome che avrebbe la PNG (es. `C03-step2.mp4`). Le fasi miste sono ammesse: `.f1` immagine e `.f2` video.
- I minivideo **muti** partono da soli appena lo step compare e vanno in **loop** finché non si avanza.
- I minivideo **parlati** (suffisso `.audio`, es. `C03-step2.audio.mp4`) partono da soli **con l'audio** e si fermano sull'ultimo frame. Se il browser blocca l'avvio con audio, compare un pulsante play: avvia il video senza far avanzare la slide.
- Click sulla slide, → e ← funzionano come prima. Cambiando slide il video precedente si ferma, senza audio residuo.
- Lo step successivo viene **precaricato** mentre si è su quello corrente, quindi immagini e video compaiono senza attese.
- Immagini e video restano nella **cache del browser**: alla call successiva partono all'istante. Se un file viene ri-esportato con lo stesso nome, il browser scarica automaticamente la versione nuova.
- Gli 11 `.mp4` segnaposto già presenti in `criticalities/` sono ora visibili nel flusso (es. C02-step3, C04-step4, C10-step1, C09-step4.f2). `C04-step3.mov` è stato convertito in `C04-step3.mp4` (18,1 MB → 1,9 MB).
- Nuovo script `bin/convert-minivideo` per convertire i `.mov` in `.mp4` adatti al web (richiede `ffmpeg`). I `.mov` sono ignorati da git.

## Cosa è stato costruito

### Grammatica e risoluzione (`app/models/content_config.rb`)
- Grammatica: `C<NN>-step<Y>[-<token>][.f<Z>][.audio].<png|mp4>`. `parse_asset_name` riconosce l'estensione (`MEDIA_KINDS`: `png` → `image`, `mp4` → `video`), stacca `.audio` (solo sui video, solo come ultimo pezzo) e poi fase e token come prima. Ogni altra estensione (`.mov`, `.webm`) e `.audio.png` ⇒ `nil`. `-audio` col trattino resta un token, quindi un file mai mostrato, come per `-f1`.
- I video contano per la struttura step/fasi esattamente come le PNG di default. `structure_in_dir`/`step_structure` hanno la stessa logica di prima, cambia solo l'insieme dei file riconosciuti.
- `resolve_phase_url` → `resolve_phase` + `media_in`: a ogni anello della catena `segmento+token → token condiviso → segmento → condiviso` prova i suffissi `MEDIA_SUFFIXES = .audio.mp4, .mp4, .png`, in quest'ordine. La catena resta prioritaria sull'estensione.
- `intro_steps` usa lo stesso `media_in`: i video nell'intro funzionano senza lavoro in più.

### Forma delle fasi: `{ url, kind, audio }`
- Ogni fase passa da stringa URL a oggetto `{ url, kind: "image" | "video", audio: boolean }`. Abbiamo scelto un oggetto invece di dedurre il tipo dall'URL per tre motivi: il server conosce già tipo e audio dal parsing, l'URL ora ha il `?v=` in coda (fragile da parsare lato client) e il tipo TS esplicita il contratto.
- `Present.tsx`: `advancePosition`/`backPosition` leggono solo `.phases.length`, quindi sono **invariati**. Lo step video finale di M18 resta `phases: []`.
- Adeguati i test esistenti, che ora leggono `phases[0][:url]` / `phases[0]["url"]`.

### Versione `?v=<mtime>` senza rallentare
- `asset_url` aggiunge `?v=<mtime>` (una `File.mtime` per ogni fase effettivamente risolta).
- Per non moltiplicare per tre le sonde `File.file?` (una per estensione e per anello), `steps_for`/`intro_steps` costruiscono un **indice per directory** (`asset_listing`): un `Dir.children` → `Set` per cartella, letto pigramente una volta per chiamata e condiviso tra struttura e risoluzione. Le sonde della catena diventano lookup in memoria, quindi le syscall sono meno di prima. L'indice non sopravvive alla chiamata, quindi non può diventare obsoleto tra una richiesta e l'altra.

### Servizio dei file (`PresentationAssetsController`, `config/routes.rb`)
- Route: constraint esteso da `.png` a `.(png|mp4)`. Prima un `.mp4` riceveva un 404 già dal routing. Il `.mov` resta non instradabile.
- **Range verificato, non dato per scontato.** In Rails 8.0.4 `send_file` ignora l'header `Range` e risponde sempre 200 col file intero, mentre Safari non riproduce un mp4 senza 206. `Rack::Files#serving` (rack 3.2.4) gestisce 206 + `Content-Range`, 416 e HEAD. Il controller mantiene le sue guardie (dir in whitelist, `File.basename`, estensione nota, `File.file?`) e poi delega a `Rack::Files`, inoltrandone la risposta.
- Content type esplicito per estensione (`image/png`, `video/mp4`), `Accept-Ranges: bytes`, `Cache-Control: private, max-age=31536000, immutable` per **tutti** gli asset. `private` invece di `public` perché gli asset stanno dietro autenticazione; per la cache del browser non cambia nulla.

### Player (`app/frontend/components/present/SlidePlayer.tsx`, `app/javascript/pages/Present.tsx`)
- Nuovo tipo `Phase`. `StepMedia` sceglie tra `SlideImage` (invariata) e il nuovo **`SlideVideo`**, che è distinto da `VideoSlide`, l'embed YouTube di M18, rimasto invariato.
- `SlideVideo`: `<video autoPlay playsInline preload="auto">`, montato con `key={url}`. Cambiare step o fase smonta l'elemento e con lui riproduzione e audio. Muto: `muted loop`, impostati anche via ref su `el.muted`/`defaultMuted` (React non riflette in modo affidabile l'attributo `muted`). Parlato: niente loop; `play()` esplicito in `useEffect`, e se viene rifiutato (eccetto `AbortError` da smontaggio) compare il pulsante "Avvia il video con audio", con lo stile e lo `stopPropagation` della facade M18. In caso di errore di caricamento → `MissingPlaceholder`.
- **Precaricamento**: `Present.tsx` calcola la fase successiva con l'`advancePosition` esistente e la passa come `nextPhase`. `usePreload` (solo in `useEffect`, quindi sicuro per l'SSR) crea un `Image` per le immagini o un `<video preload="auto" muted>` staccato per i video, rilasciato al cambio.

### Conversione (`bin/convert-minivideo`, `.gitignore`)
- Bash. Accetta solo `.mov` e scrive l'`.mp4` accanto con lo stesso nome logico. Parametri: H.264 `libx264 -preset slow -crf 26`, `yuv420p`, larghezza massima 1920 px, `+faststart`. `-an` se il nome non contiene `.audio`, altrimenti AAC 128k. Non sovrascrive senza `-f`, `CRF=` regolabile, stampa le dimensioni prima/dopo. Se `ffmpeg` manca esce con un messaggio chiaro (`brew install ffmpeg`).
- `.gitignore`: `content/assets/**/*.mov`.
- `C04-step3.mov` (1280×720, 63,7 s, nessuna traccia audio) → `C04-step3.mp4`, 1,9 MB, `moov` in testa.

### Contenuti
- Commit separato con le modifiche ai contenuti che erano nel working tree: cartelle dei segmenti svuotate (tutto arriva da `criticalities/`), PNG aggiornate e nuove, gli 11 `.mp4` segnaposto.

## Scoperte durante l'implementazione

- **Chrome non metteva in cache i video.** Verificando nel browser, dopo un reload le PNG arrivavano dalla cache (0 byte) mentre gli `.mp4` venivano riscaricati. Chrome conserva le risposte parziali (206, cioè tutte quelle dei `<video>`) solo con un validatore **forte**: un ETag, oppure un Last-Modified accompagnato da `Date`. `Rack::Files` invia solo `Last-Modified` e la risposta non ha `Date`. Fix: un `ETag` forte da mtime + dimensione (`"<mtime hex>-<size hex>"`, senza leggere il file). Riverificato: al secondo passaggio 0 byte e nessuna richiesta al server.
- **`Rack::Files` marca i propri errori con `x-cascade: pass`.** Il router di Rails li trasformava in 404 (un 416 diventava 404). L'header viene tolto prima di inoltrare la risposta.
- **Test dipendenti dai contenuti reali.** Lo svuotamento delle cartelle dei segmenti ha rotto due test che si appoggiavano alle PNG per segmento (extra criticità risolta sul segmento d'origine). Il controller test ora stubba `ContentConfig.steps_for` con un echo del segmento (stesso pattern di `stub_video_url_for`). Il system test crea PNG temporanee in `elettronica/` e `meccanica/` (con `mkdir_p`, perché git non traccia le cartelle vuote). Aggiornato anche il test di struttura di C01, che ora ha 4 step.
- **Collisioni tra test paralleli.** I test girano in processi paralleli: i nuovi test sul modello usano codici fittizi propri (C93–C96), il controller test usa un file C92 diverso per ogni test.
- **Brakeman.** La voce ignorata su `send_file` in questo controller è diventata obsoleta ed è stata rimossa da `config/brakeman.ignore`. Nessun warning nuovo. Resta un warning **preesistente e non legato al milestone**: "Support for Rails 8.0.4 ended on 2026-10-07" (Unmaintained Dependency). In più `bin/brakeman` usa `--ensure-latest` ed esce con errore perché Brakeman 8.0.5 non è l'ultima versione.
- **System test in locale (ambiente, non codice).** Su questo Mac (Darwin 27, Ruby 3.3) `Socket.tcp(..., connect_timeout:)` dà la porta come aperta anche quando è chiusa. `vite_ruby` crede quindi che il dev server di test su :3037 sia attivo e inoltra lì gli asset, e **tutti** i system test falliscono con `ECONNREFUSED` (anche quelli già esistenti). Workaround: `CI=1 bin/rails test:system`, che disattiva il proxy Vite e usa il build. Nessuna modifica al repo.

## Test

- `test/models/content_config_test.rb`: parsing (`.mp4`, `.audio.mp4`, token+fase+audio, `-audio` come token, `.audio.png`/`.mov`/`.webm` rifiutati), struttura con video e fasi miste, priorità `.audio.mp4 > .mp4 > .png`, catena prioritaria sull'estensione, `?v=` che cambia con l'mtime.
- `test/controllers/presentation_assets_controller_test.rb`: `video/mp4`, `Accept-Ranges`, ETag forte, `Range` → 206 + `Content-Range` + 100 byte, 416, `Cache-Control`, `.mov` → 404, invariati 404 e path traversal.
- `test/system/present_flow_test.rb`: flusso fittizio C91 risolto dal vero `steps_for` e servito dal vero controller (fixture `test/fixtures/files/minivideo.mp4` e `minivideo.audio.mp4`, clip ffmpeg di 1 s, ~30–40 KB). Il test verifica: step video muto che riproduce davvero (`currentTime > 0`), `muted && loop`, indicatori di fase, nessun `<video>` sugli step immagine, fase parlata `!muted && !loop`, pulsante di fallback che non fa avanzare (in headless l'autoplay con audio viene rifiutato), navigazione indietro, arrivo al video M18 e all'hub. A parte, render a larghezza mobile.
- Risultati: `bin/rails test` 179/179, `CI=1 bin/rails test:system` 35/35, `npm run check` e `bin/rubocop` puliti.

## Verifica manuale (Done when)

Sessione reale in `bin/dev` (segmento meccanica + C09 extra da elettronica), Chrome:
- **C04-step3** (video reale convertito) e **C04-step4**, **C10-step1** (segnaposto): partono da soli, muti, in loop. Su C04-step5 (immagine) nessun `<video>` resta nel DOM; tornando indietro il video riparte.
- **C09-step4**: `.f1` immagine (indicatori ●o) → `.f2` video muto in loop (o●). Il click sullo stage avanza a step5 e smonta il video.
- **`.audio`**: copia temporanea della fixture parlata come `C10-step2.audio.mp4`, poi rimossa. Ha vinto su `C10-step2.mp4`, è partita con l'audio (il gesto da tastiera reale è bastato) e si è fermata sull'ultimo frame (`ended`, frame 23/24). Il ramo con il pulsante è coperto dal system test.
- **Header** (curl autenticato): `200 video/mp4`, `206` + `Content-Range: bytes 0-99/1982104` su `Range: bytes=0-99`, `Cache-Control: max-age=31536000, private, immutable` anche sulle PNG, `Accept-Ranges: bytes`, ETag forte.
- **Cache**: dopo un reload nessuna richiesta al server per PNG e MP4 già visti (`transferSize` 0). Dopo `touch` su `C04-step4.mp4` (ri-export simulato) l'URL ha un nuovo `?v=` e il file viene riscaricato, mentre gli altri restano in cache. Il precaricamento è visibile nel log: ogni asset viene richiesto una volta, prima che lo step compaia.

Screenshot in `tmp/screenshots/`: `present-minivideo-step.png`, `present-minivideo-audio.png`, `present-minivideo-step-mobile.png`.
