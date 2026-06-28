# Milestone 11 — Inbound: sessione da prenotazione

## Novità nell'app

- Quando arriva una **prenotazione da HubSpot** (via webhook), l'app crea **da sola** una nuova sessione pre-valorizzata: nome e cognome del contatto, azienda, email, ruolo, categoria industriale e data dell'appuntamento sono già compilati.
- La sessione viene **assegnata automaticamente a un operatore** (configurabile), così Loredana la trova pronta nell'elenco delle sessioni senza doverla creare a mano.
- Le richieste in ingresso sono **autenticate con firma**: una richiesta non firmata o con firma errata viene rifiutata, esattamente come farebbe col vero HubSpot.
- Se la categoria industriale ricevuta non è tra quelle note all'app, la sessione viene creata comunque e il segmento resta da scegliere a inizio call.

## Cosa è stato costruito

**Modello dati**
- Migrazione `db/migrate/20260628000001_add_hubspot_fields_to_presale_sessions.rb`: aggiunge a `presale_sessions` i campi `prospect_email`, `prospect_role`, `hubspot_contact_id` (con indice non-unico) e `suggested_criticalities` (`integer[]`, default `[]`). Quest'ultimo è introdotto ora ma verrà **popolato in M12**.

**Endpoint webhook**
- Rotta: `POST /integrations/hubspot/appointments` (namespace `integrations/hubspot` in `config/routes.rb`).
- `app/controllers/integrations/hubspot/base_controller.rb`: eredita da **`ActionController::Base`** (non da `ApplicationController`) per non incappare in `allow_browser :modern`, CSRF e `require_authentication`, che bloccherebbero una chiamata server-to-server. `skip_forgery_protection` + `before_action :verify_signature` (→ `head :unauthorized` se la firma non è valida).
- `app/controllers/integrations/hubspot/appointments_controller.rb`: `create` fa il parse del raw body, delega al service e risponde `201 { id }` (raw JSON, lecito perché non passa dal router Inertia). Body non-JSON → `400`.

**Firma**
- `app/lib/hubspot.rb`: `Hubspot.webhook_secret` (da `ENV["HUBSPOT_WEBHOOK_SECRET"]`, default di sviluppo `dev-hubspot-webhook-secret`).
- `app/lib/hubspot/webhook_signature.rb`: `sign`/`valid?` con schema HubSpot v3 — `Base64(HMAC-SHA256(secret, METHOD + URL + body + timestamp))`, confronto a tempo costante, rifiuto dei timestamp più vecchi di 5 minuti. `sign` sarà **riusato dal simulatore in M13**.

**Service**
- `app/lib/hubspot/create_session_from_booking.rb`: mappa il payload flat-JSON (`contactId, firstname, lastname, company, email, jobtitle, industry, appointmentAt, salesName, location`) su una `PresaleSession`. Nome+cognome uniti in `contact_name`; `segment` valorizzato solo se `industry` è uno dei 7 id noti (`ContentConfig.segments`); appuntamento via `Time.zone.parse`. Owner = `User.find_by(email: ENV["HUBSPOT_INBOUND_OPERATOR_EMAIL"]) || User.first`; se non esiste alcun utente solleva `NoOperatorError`.

**Doc & crawler**
- `docs/integrations/hubspot-setup.md`: nuova "Appendice tecnica — Contratto inbound" con endpoint, tabella campi, schema firma e variabile `HUBSPOT_WEBHOOK_SECRET`.
- `public/robots.txt`: `Disallow: /integrations`.

**Test**
- `test/integration/integrations/hubspot/appointments_test.rb`: prenotazione firmata → `201` + sessione mappata e assegnata; `industry` ignoto → segment nil ma sessione creata; firma errata → `401` e nessuna sessione; firma assente → `401`. Suite completa verde (105 runs) e rubocop pulito.

## Decisioni non pre-specificate nel PRD

- **Base controller su `ActionController::Base`** invece di `ApplicationController` con skip multipli: più pulito e isola gli endpoint integrazione dalle concern web.
- **Parsing del payload da `request.raw_post`** (non da `params`): la firma è già verificata sul raw body, e così si evitano sorprese da params-wrapping.
- **Default del webhook secret** in sviluppo/test (`dev-hubspot-webhook-secret`) così il round-trip firmato funziona senza configurazione esterna.
- **Anti-replay**: rifiuto dei timestamp oltre 5 minuti (raccomandazione HubSpot), non esplicitato nel PRD.
- `hubspot_contact_id` con indice **non-unico**: un contatto potrebbe riprenotare; la correlazione (M12) sceglierà per id contatto.

## Cosa serve a M12

- `suggested_criticalities` esiste già sul modello (vuoto): M12 lo popolerà.
- `hubspot_contact_id` è salvato sulla sessione: è la chiave con cui l'evento `contact.propertyChange` (selezione criticità) ritroverà la sessione.
- Pattern riutilizzabili: `Integrations::Hubspot::BaseController` (per il secondo endpoint `contact_events`) e `Hubspot::WebhookSignature`.

## Scostamenti dal PRD

Nessuno sostanziale. Non è stata toccata la UI dell'elenco sessioni (come previsto): la sessione inbound è già visibile via azienda/contatto/segmento attraverso `session_summary`.
