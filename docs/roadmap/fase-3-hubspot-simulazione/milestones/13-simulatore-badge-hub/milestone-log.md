# Milestone 13 — Simulatore HubSpot + evidenza nell'hub

## Novità nell'app

- Nuova pagina admin **HubSpot Simulator** (`/admin/hubspot-simulator`): un clic su
  "Simula prenotazione da HubSpot" genera dati placeholder e mette in scena l'intero
  dialogo App↔HubSpot — firma e invia ai webhook **reali** prima una prenotazione e poi
  una selezione casuale di criticità. Niente scrittura diretta a database: è lo stesso
  round-trip firmato che farebbe il vero HubSpot.
- Dopo la simulazione la pagina mostra una **card della sessione creata** (azienda,
  contatto, email, ruolo, segmento, criticità suggerite) con link per aprirne l'hub o la
  scheda. Si possono lanciare più simulazioni di seguito.
- Nell'**hub** le criticità che il prospect ha pre-indicato come interessanti sono ora
  contrassegnate da una **stella amber**. Il contrassegno è indipendente dallo stato:
  una pillola può essere insieme **suggerita** (stella) e **completata** (scudo).
- Voce di navigazione "HubSpot Simulator" aggiunta alla barra laterale dell'area admin.

## Cosa è stato costruito

**Simulatore (round-trip reale)**
- `app/lib/hubspot/simulate_booking.rb` (`Hubspot::SimulateBooking`): genera dati
  placeholder (`generate_data` — nomi/aziende/ruoli da piccoli pool IT, `contactId` via
  `SecureRandom`, `industry` sempre un segmento **noto** così il subset non è mai vuoto,
  `appointmentAt` nei prossimi giorni), costruisce i due corpi JSON (`appointment_body`,
  `selection_body`), sceglie una selezione casuale non vuota (`random_suggested`) dal
  subset del segmento (`ContentConfig.criticalities_for_segment`) e fa due **POST firmati
  reali** via `Net::HTTP` (`post_signed`, unico punto di rete) a
  `/integrations/hubspot/appointments` e `/integrations/hubspot/contact_events`. Riusa
  `Hubspot::WebhookSignature.sign` e `Hubspot::CRITICALITY_PROPERTY`. Nessuna gemma nuova
  (`net/http` è stdlib). Ritorna una `Result` (`session_id`, `data`, `suggested_ids`).

**Pagina admin**
- Rotte (in `namespace :admin` di `config/routes.rb`): `GET hubspot-simulator` →
  `hubspot_simulator#show`, `POST hubspot-simulator/simulate` → `#simulate`.
- `app/controllers/admin/hubspot_simulator_controller.rb` (`< Admin::BaseController`):
  `simulate` invoca `Hubspot::SimulateBooking.call(base_url: request.base_url)` e
  **redireziona** (regola Inertia) con `notice` e l'id della sessione nel flash;
  `show` ricostruisce dal flash la card `createdSession` (con label segmento e label
  criticità suggerite, più gli URL di hub e setup). Errori (`NoOperatorError`, risposta
  non 2xx) tornano come redirect con `inertia: { errors: { base: … } }`.
- `app/javascript/pages/admin/hubspot-simulator.tsx`: dentro `AdminShell`, i 4 tag
  `<Head>` obbligatori, il bottone (`useForm().post`, router Inertia), notice/errore e la
  card della sessione creata con i due link. Solo token/primitive del design system.
- `app/frontend/components/AdminShell.tsx`: voce nav "HubSpot Simulator" (icona `Webhook`).

**Badge nell'hub**
- `PresaleSessionsController#present`: nuova prop `suggestedCriticalities`
  (= `@session.suggested_criticalities`).
- `app/javascript/pages/Present.tsx`: thread della prop fino a `<Hub suggested=… />`.
- `app/frontend/components/present/Hub.tsx`: nuova prop `suggested: number[]`; per ogni
  pillola, se `isSuggested`, render di una `Star` (`lucide-react`) amber
  (`fill-bm-amber text-bm-amber`) prima dell'eventuale `ShieldCheck`. Stella e scudo sono
  indipendenti → una pillola suggerita+completata mostra entrambi.

**Test**
- `test/lib/hubspot/simulate_booking_test.rb`: `generate_data` (segmento noto + forma
  completa), `random_suggested` (subset non vuoto/dedup/ordinato; vuoto per segmento
  ignoto), e prova di **contratto** — i corpi e le firme prodotti dal simulatore,
  postati ai due endpoint reali, creano la sessione e annotano le suggerite (senza socket).
- `test/controllers/admin/hubspot_simulator_controller_test.rb`: gating
  (login/non-admin), `show`, `simulate` con `SimulateBooking.call` stubbato → redirect +
  `flash[:created_session_id]` + card mostrata; ramo errore senza operatore.
- `test/controllers/presale_sessions_controller_test.rb`: `#present` espone
  `suggestedCriticalities`.
- `test/system/hubspot_simulator_test.rb`: end-to-end su server reale — il clic esegue
  il **round-trip Net::HTTP vero**, crea la sessione, e l'hub mostra `svg.lucide-star`
  insieme a `svg.lucide-shield-check`. Screenshot desktop+mobile in `tmp/screenshots/`.
- Suite unit: **122 runs, 0 failures**; system: **6 runs, 0 failures**;
  `npm run check` e `bin/rubocop` puliti.

## Decisioni non pre-specificate nel PRD

- **Trasporto del round-trip**: `Net::HTTP` verso `request.base_url` (POST reale come da
  prompt). La URL firmata combacia con `request.original_url` ricostruita dall'endpoint,
  quindi host/porta sono indifferenti. Il punto di rete è isolato in `post_signed` così i
  builder restano testabili senza socket; il round-trip reale è coperto dal system test
  (il server Puma di Capybara accetta la self-request).
- **`industry` sempre noto**: il generatore pesca solo tra i 7 segmenti dell'app, così la
  selezione casuale ha sempre un subset non vuoto da cui attingere.
- **Badge = icona stella amber inline** (scelta utente), coerente col pattern del
  `ShieldCheck` esistente e indipendente dallo stato completato.
- **Post-simulazione = card sul simulatore** (scelta utente): l'id della sessione creata
  viaggia nel **flash** oltre il redirect; `show` lo legge e costruisce la card. Permette
  simulazioni ripetute restando sulla pagina.
- **Selezione casuale `1..N`** delle suggerite (almeno una), ordinata; l'endpoint M12 la
  rende comunque idempotente e filtrata.

## Scostamenti dal PRD

Nessuno sostanziale. Outbound T2, invio email reale e anteprime email cliccabili restano
fuori scope come previsto. La pagina è auth-gated: nessuna modifica a sitemap/llms;
`/integrations` è già in `robots.txt`.
