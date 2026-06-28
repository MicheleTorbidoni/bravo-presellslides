# Milestone 12 — Subset per-segmento + selezione criticità

## Novità nell'app

- L'elenco delle criticità mostrato in call (hub), nella schermata risultato e nella pagina pubblica di recap è ora determinato **solo dalla categoria industriale** del prospect: un unico "subset di settore", coerente ovunque. Il profiling (albero) resta e continua a variare i **contenuti dentro** ogni criticità, ma non cambia più *quali* criticità compaiono.
- L'app sa ora **registrare le criticità che il prospect ha indicato come più interessanti**: quando arriva (via webhook) la sua selezione, viene annotata sulla sessione giusta, ricollegata tramite l'id contatto HubSpot.
- La selezione è **a prova di ripetizione**: re-invii o scelte multiple aggiornano l'elenco senza duplicati; selezioni per contatti o proprietà non riconosciute vengono ignorate senza errori.

## Cosa è stato costruito

**Subset per-segmento**
- `ContentConfig.criticalities_for_segment(segment:)` (`app/models/content_config.rb`): unione deduplicata delle criticità di tutti i mapping di quel segmento, in ordine canonico (id crescente); `[]` per segmento blank/ignoto. **Rimosso** il precedente `criticalities_for(segment:, operational_profile:)` (dead code dopo lo switch).
- Adeguati i 3 chiamanti: `PresaleSessionsController#present` e `#result`, `PublicRecapsController#recap_criticalities`. `video_url_for`/`steps_for` restano guidati da `operational_profile` per i contenuti interni (invariati).

**Endpoint selezione**
- Rotta `POST /integrations/hubspot/contact_events` (namespace `integrations/hubspot`).
- `app/controllers/integrations/hubspot/contact_events_controller.rb` (`< BaseController`, stessa firma di M11): parse del raw body → `Hubspot::ApplyContactEvents.call(events)` → `head :ok`; body non-JSON → `400`.
- `app/lib/hubspot/apply_contact_events.rb`: per ogni evento `contact.propertyChange` su `Hubspot::CRITICALITY_PROPERTY`, trova la sessione via `hubspot_contact_id` (la più recente del contatto), fa il parse di `propertyValue` (`;`-separato), filtra sugli id criticità validi, deduplica, ordina e **sostituisce** `suggested_criticalities` (idempotente). Ignora eventi/proprietà/contatti non riconosciuti.
- `Hubspot::CRITICALITY_PROPERTY = "presell_criticality_interests"` in `app/lib/hubspot.rb` (fonte unica per handler, doc e simulatore M13).

**Doc**
- `docs/integrations/hubspot-setup.md`: nuova "Appendice tecnica — Contratto selezione criticità" (endpoint, forma evento `contact.propertyChange`, semantica `propertyValue`, firma) e riga della proprietà custom `presell_criticality_interests` (multi-checkbox).

**Test**
- `test/models/content_config_test.rb`: sostituiti i test su `criticalities_for` con `criticalities_for_segment` (subset `meccanica`; unione/dedup/ordine per `imballaggi-e-packaging` = `[1..7]`; `[]` per ignoto/blank); aggiornato il test di completezza mapping (mantiene `mappings.size == segmenti×profili` e ogni mapping non vuoto, senza usare il metodo rimosso).
- `test/controllers/presale_sessions_controller_test.rb`: il test "fallback no mapping" ora usa un **segmento ignoto** e verifica `prefiltered: false` + 13 criticità.
- Nuovo `test/integration/integrations/hubspot/contact_events_test.rb`: selezione firmata → annotata (filtrata/dedup/ordinata); idempotenza (replace); id ignoti scartati; contatto sconosciuto → no-op `200`; altra proprietà → ignorata; firma errata → `401`.
- Suite completa: **111 runs, 0 failures**; rubocop pulito.

## Decisioni non pre-specificate nel PRD

- **Rimozione** di `criticalities_for` invece di affiancarlo: evita dead code, dato che il subset non dipende più dal profilo.
- **Ordine canonico** (id crescente) per l'unione: normalizza anche i mapping che dichiarano gli id fuori ordine (es. `imballaggi-e-packaging`).
- **Filtro sugli id criticità validi** (1..13) e non sul subset del segmento: robusto anche quando il segmento è vuoto (industry ignota all'inbound), così la selezione non viene azzerata.
- **Replace** (non accumulo) di `suggested_criticalities`: coerente con la semantica del multi-checkbox HubSpot, in cui ogni evento porta il valore completo.
- Correlazione alla **sessione più recente** del contatto (un contatto potrebbe riprenotare).

## Cosa serve a M13

- `suggested_criticalities` è ora popolato dall'endpoint: M13 lo passerà all'hub come prop e disegnerà il badge.
- `Hubspot::CRITICALITY_PROPERTY` e `Hubspot::WebhookSignature.sign` sono pronti per il simulatore, che genererà una selezione casuale dal subset di segmento (`ContentConfig.criticalities_for_segment`) e firmerà l'evento.
- Entrambi gli endpoint reali (`appointments`, `contact_events`) sono disponibili per il round-trip del simulatore.

## Scostamenti dal PRD

Nessuno. La UI dell'hub (badge/prop suggerite) resta intatta, come previsto: è scope di M13.
