# Milestone 20 — Log

## Novità nell'app

- Il **Setup sessione** è ora l'unica schermata di configurazione e compare **una sola volta**, subito dopo la creazione della sessione. Contiene dati del prospect, segmento, **tutte le 13 criticità** (abilitazione + ordine con trascinamento) e le caselle "Mostra l'introduzione all'inizio" / "Mostra l'hub tra le criticità", già spuntate.
- Qualsiasi criticità si può abilitare per qualsiasi segmento. All'apertura nessuna è spuntata, tranne quelle indicate dal prospect su HubSpot.
- Le criticità associate al segmento in `mappings.json` mostrano il badge **"Tipica del segmento"**. Cambiare segmento sposta il badge e non tocca la selezione.
- Dopo la **Profilazione** si entra direttamente nella **Presentazione**: il riepilogo del Setup dopo il questionario non esiste più.
- Il pannello "Aggiungi criticità da un altro segmento" (M14) è stato rimosso, perché ormai superfluo.
- Il recap pubblico mostra le criticità abilitate dall'operatore, nel suo ordine.

## Cosa è stato costruito

### Modello (`app/models/presale_session.rb`)
- La logica di selezione e ordine, prima privata nel controller, passa nel modello per essere condivisa da Setup, Presentazione e recap:
  - `effective_selected_criticalities`: se la selezione è `nil` (mai scelta) si usano i suggerimenti HubSpot, altrimenti la selezione esplicita (anche `[]`). In entrambi i casi è limitata al catalogo di `criticalities.json`, non più al sottoinsieme del segmento.
  - `effective_criticalities_order`: l'ordine salvato, limitato al catalogo, con in coda gli id mancanti in ordine canonico.
  - `presented_criticalities`: le criticità abilitate nell'ordine scelto.
- Non c'è più il default "unione HubSpot + mappatura segmento×profilo": la profilazione arriva dopo il Setup.

### Controller
- `PresaleSessionsController#setup`: nuove props `criticalities` (catalogo completo) e `segmentCriticalities` (`{ segmento => [id] }`, solo per il badge). Rimosse `criticalitiesBySegment` ed `extraCriticalities`.
- `#present` usa `presented_criticalities`. `steps_by_criticality` risolve ogni criticità sul segmento della sessione: le slide di una criticità non tipica del segmento ricadono su quelle condivise.
- Rimossi `extra_segment_by_id`/`allowed_ids` e il parametro `extra_criticalities` dall'auto-save.
- `PublicRecapsController#recap_criticalities`: si basa sulla selezione dell'operatore (riserva: tutte e 13) più le eventuali criticità discusse fuori selezione. Rimosso `extra_recap_criticalities`.
- `ContentConfig.criticalities_for` (mappatura segmento×profilo per la preselezione) è stato rimosso perché inutilizzato. `criticalities_for_segment` resta, ma serve solo al badge.

### Frontend
- `Setup.tsx`: niente più modalità light/full né pannello extra. Il gate di "Avanti" richiede segmento + almeno una criticità e porta alla Profilazione. Badge "Tipica del segmento" con il `Badge` neutro del design system.
- `Profiling.tsx`: "Avanti" porta a `/present`. Il sottotitolo ora dice che le domande in evidenza personalizzano le slide.

### Dati esistenti
- Nessuna migrazione. Le sessioni con `extra_criticalities` (M14) mantengono le loro criticità, perché gli id restano in `selected_criticalities`. Le relative slide però ora si risolvono sul segmento della sessione.

### Test
- Riscritti `setup_stages_test.rb` (elenco completo, caselle spuntate, badge al cambio segmento, gate, suggerimenti HubSpot, larghezza mobile) e `session_flow_order_test.rb` (Setup → Profilazione → Presentazione).
- Rimosso `setup_extra_criticalities_test.rb`. Aggiornati i test di controller (setup/present/recap), `profiling_all_at_once_test.rb`, `present_flow_test.rb` e `content_config_test.rb`.
- Screenshot di verifica in `tmp/screenshots/setup-single.png` e `tmp/screenshots/setup-single-mobile.png`.
