# Milestone 5 — Stile Figma & template slide — Log

## Novità nell'app

- **Veste grafica Bravo Manufacturing** su tutte le superfici mostrate al prospect: ora hanno l'aspetto dei mockup Figma, non più il placeholder funzionale.
- **Hub "Dove fa più difficoltà…"**: sfondo grigio chiaro, titolo in stile brand, **criticità come pillole verdi a parallelogramma**; **un clic sulla pillola avvia subito** la presentazione di quella criticità (niente bottone separato); le criticità già viste restano marcate con la spunta; logo Bravo in basso a sinistra.
- **Slide di presentazione**: sfondo verde brand, titolo bianco in alto, grande area centrale per il contenuto visivo, logo in basso a sinistra.
- **Pagina di chiusura**: sfondo slate, "Grazie, [Nome]" e messaggio centrati col nome del contatto e dell'azienda, logo centrato.
- **Font del brand (Outfit)** e **logo Bravo Manufacturing reale** (vettoriale, due varianti cromatiche) su tutte le superfici prospect.
- Tutte e tre le superfici restano nella **stessa cornice 16:9** e i contenuti **scalano** con la dimensione del palco.
- Il comportamento è **identico** a prima: navigazione, scorciatoie, cattura domande e flusso invariati — cambia solo la veste.

---

## Cosa è stato costruito

### Token & font (contesto prospect autonomo)
- `app/frontend/styles/prospect.css` (**nuovo**) — blocco `@theme` con token **prefissati `bm-`** (non collidono col design system del template): `--color-bm-green #7AAD1A`, `--color-bm-green-bright #7AC142`, `--color-bm-amber #F7B307`, `--color-bm-slate #5F677F`, `--color-bm-grey #EEEEEE`, `--color-bm-white #FFFFFF`, `--font-bm "Outfit"`. Tailwind v4 genera le utility `bg-bm-green`, `text-bm-slate`, `font-bm`, ecc.
- `app/javascript/entrypoints/application.css` — import di `prospect.css` dopo il blocco `bm-design-system`.
- `app/views/layouts/application.html.erb` — `<link>` Google Fonts **Outfit** (pesi 400–700), fuori dal blocco gestito dalla skill, riusando i preconnect esistenti.
- `app/frontend/vite-env.d.ts` (**nuovo**) — `/// <reference types="vite/client" />` per tipare gli import SVG.

### Logo
- `app/frontend/assets/prospect/bravo-logo-color.svg` e `bravo-logo-white.svg` (**nuovi**) — esportati dal Figma (Logo Container dei nodi 62-241 e 67-32) e **ripuliti** dei rettangoli di sfondo. Color = bravo slate + check verde brillante + manufacturing verde; white = tutto bianco col check verde.
- `app/frontend/components/present/Logo.tsx` (**nuovo**) — `<Logo variant="color" | "white" />`, import SVG → URL (SSR-safe). Sostituisce il wordmark testuale di M4.

### Restyling componenti prospect (comportamento invariato)
- `Stage.tsx` — la cornice 16:9 non impone più lo sfondo: aggiunta prop `className` (ogni superficie passa il proprio sfondo) + `font-bm` + `[container-type:inline-size]` per abilitare le unità **`cqw`** (i contenuti scalano col palco).
- `Hub.tsx` — `bg-bm-grey`, titolo `text-bm-slate` Outfit bold a sinistra, **pillole a parallelogramma** (`-skew-x-12` sul bottone + `skew-x-12` sul label) verdi/bianco. **Interazione: clic sulla pillola = `onPick(id)` → avvia subito il flow di quella criticità** (rimossi il bottone "Avvia/Continua" e lo stato "selezionata": erano causa di confusione — il bottone finiva sotto la piega dello stage 16:9 senza scroll). Due soli stati: **disponibile** (verde, testo bianco) e **completata** (pillola bianca + testo arancio + `ShieldCheck`, il look "evidenziato" del mockup Figma 62-619; ri-apribile). Logo colore in basso a sx; hint discreto "Tocca un tema… · `C` per chiudere".
- `SlidePlayer.tsx` — `bg-bm-green`, titolo bianco Outfit in alto a sx, body bianco, area contenuto centrata (`object-contain`, placeholder in tinta su PNG mancante), dots sequence bianco/bianco-40, logo bianco in basso a sx. `interpolate()`/`assetUrl()` invariati.
- `Closing.tsx` — `bg-bm-slate`, titolo + body bianchi **centrati** Outfit, pulsanti operatore in tinta sobria, logo bianco centrato.
- `QuestionCapture.tsx` — overlay operatore allineato al brand (card bianca, testo slate, salva verde, focus verde), `font-bm`. Resta a dimensioni px (modale a viewport, non scala col palco).

### Verifica
- `bin/rails test` → **60 run, 207 assertions, 0 failure** (incl. `ssr_smoke_test`: componenti + Logo SVG SSR-safe).
- `bin/rails test:system` → **2 run, 21 assertions, 0 failure** (al re-run; vedi nota flakiness login).
- `npm run check` pulito · `bin/rubocop` pulito (64 file).
- Screenshot `tmp/screenshots/present-{hub,slide-concept,closing}.png` confrontati coi mockup `/tmp/figma-*.png`: corrispondenza fedele (grigio+pillole verdi / verde+titolo bianco / slate centrato).

---

## Decisioni prese (non pre-specificate nel PRD)

- **Scaling con `cqw`**: lo stage è reso un *container* (`container-type: inline-size`) e i contenuti usano unità `cqw` (≈ px-Figma ÷ 19.2 su base 1920), così tutto scala in proporzione al palco a qualsiasi risoluzione. Alternativa scartata: dimensioni `vh` (meno precise col letterbox).
- **Un solo chrome per i 3 tipi di slide**: il Figma ha un unico template slide (`stepcriticita`); concept/screenshot/sequence lo condividono e differiscono solo per contenuto/`body`. **Nessun campo `template` aggiunto a `slides.json`** (il `type` esistente basta) → player M4 retro-compatibile, nessun cambio allo schema.
- **Interazione hub = clic sulla pillola avvia subito** (deciso con l'utente dopo M5): il bottone "Avvia presentazione" finiva sotto la piega dello stage 16:9 (`overflow-hidden`, niente scroll) ed era invisibile; inoltre lo stato "selezionata" (bianco + scudo) sembrava "completata". Rimossi bottone e stato di selezione. `Present.tsx`: tolti `selected`/`toggle`/`start`, aggiunto `pick(id)`. Stato "completata" delle pillole = pillola bianca + testo arancio + `ShieldCheck` (riusa il look "evidenziato" del mockup Figma 62-619), ri-apribile.
- **Robustezza system test (login)**: `fill_in` di Capybara non innesca affidabilmente l'`onChange` React sugli input controllati in headless (il valore non si fissa → validazione HTML5 "compila questo campo"). Aggiunto helper `react_fill` (setter nativo + evento `input`), come già fatto per il `<textarea>`. Risolve la flakiness del login nota da M3.
- **Affordance operatore** sullo schermo prospect (hint `C`, pulsanti chiusura) mantenute ma rese discrete/in tinta.
- **Font Outfit via Google Fonts** in `<head>` (le call sono online via OBS); self-hosting rimandato.
- **Logo esportato come SVG** (2 varianti) e ripulito dai rettangoli di sfondo, anziché ricreato a mano.
- **`vite-env.d.ts`** aggiunto per tipare gli import SVG (prima assente nel repo).

---

## Cosa deve sapere il milestone successivo (M6 — Debrief & email recap)

- M6 è una **schermata interna** (non mostrata al prospect): usa il **design system del template** (`components/ui/`), **non** i token `bm-`. I token `bm-` e i componenti `present/` sono esclusivi del contesto prospect.
- La pagina di chiusura ha il pulsante **"Vai al debrief" disabilitato** (placeholder): M6 lo abiliterà per raggiungere il debrief.
- Le **domande catturate** vivono in `presale_sessions.captured_questions` (jsonb, voci con `id` stabile) — il debrief le legge/edita da lì.
- La convenzione "chrome + PNG trasparente" è formalizzata: l'area contenuto delle slide ospita PNG trasparenti per slide/segmento; il contenuto grafico reale resta da produrre (fuori scope).

---

## Scostamenti dal PRD

- **Nessun adeguamento a `slides.json`**: il PRD prevedeva un "eventuale" campo `template`; non necessario perché il `type` esistente già seleziona il template e il chrome è unico. Player M4 resta invariato e retro-compatibile.
- Per il resto i criteri "Fatto quando" di M5 sono soddisfatti: hub, chiusura e i 3 tipi di slide appaiono con la veste Figma; titolo/body sono testo live con le variabili dentro la cornice stilizzata; il contenuto è una PNG (placeholder) per slide/segmento; il comportamento di M3/M4 è invariato.

## Note / heads-up
- **Flakiness login nei system test risolta**: la causa era `fill_in` che non fissava il valore sugli input React controllati in headless (submit → validazione HTML5). Ora si usa `react_fill` (setter nativo + evento `input`); il test gira stabile su run ripetuti.
