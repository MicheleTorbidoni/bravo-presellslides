# Milestone 10 — Appuntamento col commerciale

## Novità nell'app

- Nel **debrief**, Loredana può fissare un **appuntamento di follow-up** col commerciale: data/ora, nome del commerciale e luogo o link videocall (salvataggio automatico).
- Se impostato, l'appuntamento compare come **promemoria** sia nell'**email di recap** sia nella **pagina pubblica** del prospect.
- Il prospect può **aggiungere l'appuntamento al proprio calendario**: file `.ics` universale (Apple/Outlook/Google) e bottone **"Aggiungi a Google Calendar"** in pagina; l'email allega direttamente l'invito `.ics`.
- È tutto **opzionale**: se non c'è un appuntamento, email e pagina non mostrano nulla e il recap si invia comunque.

## Cosa è stato costruito

### Backend

- **Migration** `db/migrate/20260622150000_add_appointment_to_presale_sessions.rb` — colonne `appointment_at` (datetime), `appointment_sales_name` (string), `appointment_location` (string).
- **`config/application.rb`** — `config.time_zone = "Europe/Rome"` (storage resta UTC). Necessario perché l'input `datetime-local` è un orario "a muro" senza fuso: così viene interpretato e formattato in ora italiana lungo il path generico di auto-save, a prescindere dal browser dell'operatore.
- **`app/models/presale_session.rb`** — helper `appointment?` (true se `appointment_at` presente).
- **`app/lib/appointment_calendar.rb`** (nuovo PORO) — `ics(session)` genera il VCALENDAR/VEVENT (UID stabile, DTSTAMP, DTSTART/DTEND in UTC, SUMMARY/DESCRIPTION/LOCATION con escaping RFC 5545, durata fissa 30 min); `google_url(session)` genera il link "Aggiungi a Google Calendar". Nessuna gem aggiunta.
- **`app/controllers/presale_sessions_controller.rb`** — `session_params` permette i tre campi; `session_detail` espone `appointment_at_local` (stringa `YYYY-MM-DDTHH:MM` in ora di Roma per l'input), `appointment_sales_name`, `appointment_location`.
- **`config/routes.rb`** — `GET /r/:token/calendar.ics` → `public_recaps#calendar` (`public_recap_calendar`). Coperto dal `Disallow: /r/` già presente.
- **`app/controllers/public_recaps_controller.rb`** — `show` aggiunge la prop `appointment` (nil se assente; altrimenti `display`, `sales_name`, `location`, `ics_url`, `google_url`); nuova action `calendar` che fa `send_data` dell'`.ics` (404 se manca l'appuntamento), pubblica come il resto del controller.
- **`app/mailers/presale_recap_mailer.rb`** — se la sessione ha un appuntamento: ivar per il blocco promemoria + allegato `appuntamento.ics` (`text/calendar`).
- **View mailer** `recap.html.erb` / `recap.text.erb` — blocco promemoria appuntamento (data/ora Roma + commerciale + luogo) prima del bottone alla pagina, solo se presente.

### Frontend

- **`app/javascript/pages/PresaleSessions/Debrief.tsx`** — blocco "Appuntamento col commerciale" (datetime-local + commerciale + luogo) con auto-save debounced (stesso pattern delle domande). Tipi props aggiornati con i campi `appointment_*`.
- **`app/javascript/pages/PublicRecap.tsx`** — sezione appuntamento (se presente) con data/ora, commerciale, luogo e due bottoni: "Aggiungi al calendario" (`.ics`) e "Google Calendar".

### Test

- `AppointmentCalendar`: `.ics` con VEVENT/DTSTART/SUMMARY/LOCATION (escaping virgole) e UID stabile; conversione 15:00 Roma → 13:00 UTC (DST); `google_url` con date UTC; nil senza appuntamento.
- Mailer: con appuntamento → allegato `text/calendar` + promemoria nel testo/HTML; senza → nessun allegato.
- `PublicRecapsController`: prop `appointment` presente/nil; `calendar` serve `text/calendar` **senza login**; 404 senza appuntamento.
- Auto-save: i tre campi si persistono; round-trip `appointment_at_local` in ora di Roma.
- Mailer preview `recap_with_appointment` aggiunta.

## Decisioni prese (non pre-specificate nel PRD)

- **Fuso orario applicativo Europe/Rome** (app monolingua IT) per evitare drift tra input `datetime-local` e visualizzazione/`.ics`. Storage invariato (UTC).
- **`.ics` generato a mano** in un PORO riusabile (endpoint pubblico + allegato mailer), senza introdurre la gem `icalendar`.
- **Durata evento fissa 30 minuti** (non esposta in UI).
- **Round-trip via `appointment_at_local`**: il backend invia/riceve l'orario a muro di Roma come stringa, così l'input è stabile indipendentemente dal fuso del browser.

## Scostamenti dal PRD

Nessuno. Tutti i criteri "Fatto quando" sono coperti. *Nota di verifica:* suite (`bin/rails test` → 96 runs, 0 failures), `npm run check`, rubocop e un render SSR della pagina pubblica con appuntamento passano; la verifica UI interattiva con `agent-browser` non è disponibile in questa sessione e va ripresa manualmente (impostazione appuntamento nel debrief, bottoni calendario in pagina, allegato `.ics` nell'email via preview).
