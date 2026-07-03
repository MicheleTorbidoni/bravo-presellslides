# Bravo Manufacturing Pre-Sale Tool — Fase 5: Questionario esteso

> **Informazioni su questi file di roadmap:** questa cartella (`docs/roadmap/fase-5-questionario-esteso/`) contiene il PRD e i prompt della **Fase 5** dell'app, un incremento costruito **sopra** i milestone già rilasciati (fino a M14). A differenza di `_build_plan/` (lo scaffold iniziale, destinato alla cancellazione), questa cartella documenta un'evoluzione del prodotto a partire dal codice esistente. Resta comunque un artefatto di guida: nessun codice, configurazione o logica di runtime deve importare o dipendere da questi file. La fonte di verità è il codice.

## Cosa stiamo costruendo

La schermata di **Profilazione** (interna, usata da Loredana durante la prima call) oggi contiene solo l'**albero decisionale**: 5 domande a scelta singola che generano l'`operational_profile` (i token che guidano le slide delle criticità). Dalla PR #35 queste 5 domande sono mostrate tutte insieme, con disabilitazione a cascata dei rami esclusi.

La Fase 5 **estende questa stessa schermata** con un questionario di qualificazione commerciale molto più ampio (~24 domande aggiuntive): dati sull'interlocutore, sull'azienda, sulla motivazione del contatto, sugli obiettivi, sulla situazione attuale, sulle criticità e sulle aspettative. Queste domande **non hanno alcun impatto sui token né sulle slide**: servono a informare il commerciale per l'eventuale incontro successivo (non gestito dall'app).

Le domande "criticità" (l'albero) e le domande "extra" convivono in **un'unica lista raggruppata per contesto semantico**, così che domande affini siano vicine — questo significa che le 5 domande-criticità sono **interlacciate** dentro i gruppi tematici, non isolate in cima. Le domande-criticità restano **visivamente distinte** (card con sfondo accent tenue) e un **toggle in testa** permette di vedere solo loro, per capire a colpo d'occhio cosa manca per "procedere" alla presentazione.

L'app è Rails 8 + React 19 + Inertia. La Fase 5 è costruita in **due milestone** (M15 framework, M16 rifiniture) sul modello dati e sulle superfici esistenti. Nessuna modifica alla logica dei token: `content/config/decision-tree.json` resta la fonte autorevole di criticità e `operational_profile`.

### Cosa fa l'app (novità della Fase 5)

- La Profilazione mostra, oltre alle 5 domande-criticità, **tutte le domande di qualificazione commerciale**, organizzate in **gruppi semantici** (Interlocutore, Azienda, Produzione & macchine, Gestione & software, Motivazione, Obiettivi, Criticità attuali, Miglioramenti, Aspettative, Conclusione).
- Le domande-criticità sono **interlacciate** nei gruppi pertinenti e rese **visivamente distinte** con una card a sfondo accent tenue; le domande extra hanno stile neutro.
- Le domande extra usano **tipi di campo nuovi**: scelta multipla (checkbox), testo, numero intero, valuta, percentuale, sì/no, testo lungo.
- Un **toggle "Mostra solo domande per le criticità"** in testa filtra la vista alle sole domande-criticità, per verificare cosa manca prima di procedere.
- Le risposte si **salvano automaticamente** durante la compilazione e si **ripristinano** ricaricando la pagina (la call può interrompersi senza perdere nulla).
- Il pulsante **"Avanti"** verso la presentazione resta legato **solo** alle domande-criticità sul percorso attivo: le domande extra non bloccano mai l'avanzamento.
- (M16) I campi di dettaglio compaiono **solo quando servono** (es. "specifica Altro", "% conto terzi" solo se conto terzi = sì); il **totale persone** si auto-calcola dalla somma dei conteggi ed è correggibile a mano.

### Già fornito dal codice esistente (da riusare, non ri-specificare)

- **Profilazione all-at-once**: `app/javascript/pages/PresaleSessions/Profiling.tsx` già mostra tutte le domande dell'albero insieme, calcola le domande abilitate con un walk generico dallo `start` e ricostruisce `operational_profile` in ordine deterministico (walk lungo i rami risposti). Il gate "Avanti" è già "walk completo fino a una foglia".
- **Config statica**: `ContentConfig` (`decision_tree`, `load_config`) legge i JSON in `content/config/` e li ri-legge a ogni chiamata fuori produzione (edit senza restart).
- **Persistenza per-sessione con auto-save**: il **Setup** (`Setup.tsx`) e il controller `PresaleSessionsController#update` implementano già il pattern auto-save debounced su campi della sessione via `apiPatch` — da riusare come riferimento per il questionario.
- **Colonne jsonb su `PresaleSession`**: `captured_questions`, `extra_criticalities` sono precedenti jsonb per-sessione; stesso pattern per il nuovo campo.
- **Design system**: primitive `Checkbox`, `Radio`/`RadioGroup`, `Input`, `Select`, `Badge`, token (`bg-surface`, `bg-accent/5`, `border-hairline`, ecc.). Riferimento `/admin/design-system`.

### Fuori scope (Fase 5)

- **Nessun impatto su token/criticità/slide**: le domande extra non toccano `operational_profile`, `decision-tree.json`, `mappings.json`, `slides`. Il gate di avanzamento resta guidato solo dalle domande-criticità.
- **Nessuna sync HubSpot** delle risposte: le chiavi del questionario sono scelte per mappare 1:1 le future proprietà HubSpot (vedi Fase 3), ma l'invio/lettura verso HubSpot è fuori scope qui.
- **Nessuna esposizione delle risposte a valle**: mostrare/estrarre le risposte per il commerciale (debrief, recap, export, CRM) è fuori scope in questa fase. La Fase 5 si occupa solo di **raccogliere e persistere**.
- **Nessuna obbligatorietà delle domande extra**: nessuna domanda extra è richiesta per procedere né per "completare" la call.
- **Nessuna traduzione/localizzazione**, nessuna gestione multi-utente delle risposte: valgono le regole di accesso già in essere sulla sessione.

### Modello dati

**PresaleSession (campo aggiunto)**

- **qualification_answers** — le risposte alle domande di qualificazione commerciale per questa call. È una mappa "chiave del campo → valore", dove le chiavi sono i nomi dei campi definiti nel questionario (es. `contact_roles`, `annual_turnover_amount`, `does_subcontract_manufacturing`). I valori seguono il tipo del campo: elenco di stringhe per la scelta multipla, numero per interi/valuta/percentuale, vero/falso per i sì/no, testo per i campi liberi. Vuoto di default. Le chiavi sono scelte per corrispondere alle **future proprietà HubSpot**, così che una successiva sync outbound sia un mapping diretto.

Nota: `operational_profile` (i token delle domande-criticità) resta il campo esistente e **non** confluisce in `qualification_answers`. Le due cose sono distinte: i token guidano le slide, le risposte di qualificazione informano il commerciale.

**Config statica (file nuovo)**

- **`content/config/questionnaire.json`** — descrive la lista unificata: un elenco ordinato di **gruppi semantici**; ogni gruppo ha un titolo e una lista ordinata di **elementi**. Un elemento è **o** un riferimento a una domanda dell'albero decisionale (`{ "ref": "d1" }` → domanda-criticità, resa con lo stile accent) **o** un **campo extra** inline con: nome del campo (chiave in `qualification_answers`), etichetta, tipo, eventuali opzioni, ed eventuale condizione di visibilità (`visible_if`, usata solo in M16). La distinzione criticità/extra è **intrinseca**: i `ref` sono criticità, i campi inline sono extra.

---

## Milestone M15 — Questionario esteso: framework

Estende la Profilazione con il questionario di qualificazione: lista unica raggruppata per contesto, domande-criticità interlacciate e visivamente distinte, tipi di campo nuovi, toggle "solo criticità", auto-save e ripristino. In questo milestone **tutti** i campi sono sempre visibili (le condizioni di visibilità arrivano in M16).

### Cosa viene costruito

- **Colonna `qualification_answers` (jsonb)** su `PresaleSession`, vuota di default, aggiornabile via l'auto-save del questionario.
- **`content/config/questionnaire.json`**: i gruppi semantici e gli elementi (ref alle domande-criticità + campi extra), popolato con l'intero contenuto dell'Appendice A di questo PRD.
- **Rendering unificato a gruppi** in `Profiling.tsx`: per ogni gruppo, il titolo e i suoi elementi in ordine; i `ref` risolvono la relativa domanda dell'albero (con la disabilitazione a cascata già esistente), i campi inline rendono il tipo appropriato.
- **Primitive di campo** per: scelta multipla (checkbox), testo, intero, valuta, percentuale, sì/no (coppia di radio), testo lungo. Il testo lungo richiede un nuovo primitivo **`Textarea`** aggiunto al design system (`components/ui/textarea.tsx` + sezione su `/admin/design-system`).
- **Distinzione visiva**: le card delle domande-criticità hanno **sfondo accent tenue**; le domande extra hanno stile neutro.
- **Toggle "Mostra solo domande per le criticità"** in testa: filtra la vista ai soli elementi `ref`.
- **Gate "Avanti" invariato**: resta legato al walk delle sole domande-criticità sul percorso attivo; le risposte extra non incidono. Il toggle serve proprio a vedere quali domande-criticità mancano.
- **Persistenza**: auto-save debounced di `qualification_answers` (e dell'`operational_profile` già gestito) verso la sessione; **ripristino** dei valori — criticità ed extra — al ricaricamento della pagina.
- **Test** (controller/config + system test della UX) e **screenshot** desktop + mobile.

### Cosa la milestone M15 esplicitamente NON include

- **Visibilità condizionale** dei campi (`visible_if`): in M15 i campi di dettaglio (es. "specifica Altro", "% conto terzi", "nome software", "ruolo Altro") sono **sempre visibili**. Il comportamento hide/show arriva in M16.
- **Auto-somma "Totale persone"** e qualsiasi calcolo derivato tra campi: M16.
- **Validazioni** sui valori (numeri ≥ 0, percentuali 0–100, ecc.): M16.
- **Sync HubSpot** e **esposizione delle risposte** a debrief/recap/export: fuori scope Fase 5.

### Done when

Aprendo la Profilazione di una sessione, Loredana vede le domande organizzate nei gruppi semantici, con le domande-criticità interlacciate e riconoscibili (sfondo accent) e le nuove domande extra compilabili nei vari tipi (scelta multipla, numeri, valuta, sì/no, testo). Il toggle "solo criticità" nasconde le extra e lascia vedere quali domande-criticità restano da rispondere; "Avanti" si abilita solo quando le domande-criticità sul percorso attivo sono complete. Compilando alcune domande e ricaricando la pagina, i valori si ripristinano; le risposte extra sono persistite in `qualification_answers`. La suite `bin/rails test` passa al 100%.

---

## Milestone M16 — Questionario esteso: condizionali e rifiniture

Aggiunge la logica di visibilità condizionale dei campi di dettaglio, l'auto-somma del totale persone e le validazioni leggere.

### Cosa viene costruito

- **Visibilità condizionale (`visible_if`)**: i campi di dettaglio compaiono solo quando la condizione è vera:
  - `contact_role_other` (testo) — solo se `contact_roles` contiene "Altro".
  - `subcontract_turnover_percentage` — solo se `does_subcontract_manufacturing` = sì.
  - `production_management_software_name` — solo se `has_production_management_software` = sì.
  - i campi `*_other_text` (testo lungo) — solo se la relativa scelta multipla contiene "Altro".
- **Auto-somma "Totale persone"**: `total_people_count` si calcola come somma di operatori di produzione + ufficio tecnico + amministrazione + altre persone d'ufficio, e resta **correggibile a mano** (un override manuale non viene sovrascritto dai successivi cambi dei conteggi finché l'operatore non lo azzera).
- **Validazioni leggere**: numeri interi ≥ 0, percentuali 0–100, valuta ≥ 0; feedback inline non bloccante coerente col design system.
- **Test** delle condizioni di visibilità, dell'auto-somma e delle validazioni.

### Cosa la milestone M16 esplicitamente NON include

- **Sync HubSpot** ed **esposizione** delle risposte a valle: restano fuori scope Fase 5.
- Regole di validazione complesse o cross-campo oltre a quelle elencate.

### Done when

Nella Profilazione, i campi di dettaglio appaiono e scompaiono correttamente al variare delle risposte "guida" (Altro, conto terzi, software gestionale); il totale persone si aggiorna sommando i conteggi e può essere corretto a mano; valori numerici non validi mostrano un feedback inline. La suite `bin/rails test` passa al 100%.

---

## Appendice A — Contenuto del questionario (fonte di verità in-repo)

Gruppi in ordine di visualizzazione. 🔶 = domanda-criticità (riferimento all'albero, `{ "ref": "…" }`, stile accent). Le altre voci sono campi extra inline (chiave = nome del campo in `qualification_answers`).

### 1. Interlocutore
- **contact_roles** — "Di cosa si occupa in azienda?" — scelta multipla: Titolare / Amministratore · Socio · Responsabile Commessa · Responsabile Produzione · Direttore di Stabilimento · Responsabile Amministrativo · Responsabile IT · Responsabile Acquisti · Consulente · Impiegato/a · Altro
- **contact_role_other** — "Specifica" — testo — *visible_if: `contact_roles` contiene "Altro"* (M16)

### 2. Azienda
- **production_operators_count** — "Operatori di produzione" — intero
- **technical_office_people_count** — "Persone nell'ufficio tecnico" — intero
- **administrative_people_count** — "Persone in amministrazione" — intero
- **other_office_people_count** — "Altre persone d'ufficio" — intero
- **total_people_count** — "Totale persone" — intero — *auto-somma dei quattro precedenti, sovrascrivibile a mano* (M16)
- **annual_turnover_amount** — "Fatturato annuo" — valuta
- **does_subcontract_manufacturing** — "Svolgete lavorazioni conto terzi?" — sì/no
- **subcontract_turnover_percentage** — "Quanto incidono sul fatturato?" — percentuale — *visible_if: `does_subcontract_manufacturing` = sì* (M16)
- **does_outsource_work** — "Affidate alcune lavorazioni in outsourcing?" — sì/no

### 3. Produzione & macchine
- 🔶 **ref d1** — "La produzione è Human Only?"
- 🔶 **ref d2** — "Avete macchine IoT?"

### 4. Gestione & software
- 🔶 **ref d3** — "La produzione è gestita con..."
- **has_production_management_software** — "Utilizzate oggi un software per gestire la produzione?" — sì/no
- **production_management_software_name** — "Quale software utilizzate?" — testo — *visible_if: `has_production_management_software` = sì* (M16)
- 🔶 **ref d4** — "Gestite le Distinte Base?"
- 🔶 **ref d5** — "Che tipo di Distinta?"

### 5. Motivazione del contatto
- **contact_reason_categories** — "Qual è il motivo principale che vi ha portato a contattarci?" — scelta multipla: Eliminare la carta · Automatizzare i processi · Digitalizzare la produzione · Abbandonare Excel · Non disponiamo di un sistema MES · Migliorare il controllo di commessa · Tracciare tempi uomo · Tracciare tempi macchina · Conoscere l'avanzamento della produzione · Interconnettere le macchine / Industria 4.0 / IoT · L'attuale fornitore software non soddisfa le esigenze produttive · Altro
- **contact_reason_other_text** — "Specifica" — testo lungo — *visible_if: `contact_reason_categories` contiene "Altro"* (M16)

### 6. Obiettivi di business
- **business_goal_categories** — "Quali risultati vorreste ottenere?" — scelta multipla: Recuperare efficienza · Ridurre i tempi di produzione · Ridurre i fermi macchina · Ridurre gli sprechi · Ridurre i costi di produzione · Ridurre gli scarti · Ottenere dati affidabili · Monitorare l'avanzamento della produzione in tempo reale · Altro
- **business_goal_other_text** — "Specifica" — testo lungo — *visible_if: `business_goal_categories` contiene "Altro"* (M16)

### 7. Criticità attuali
- **current_issue_categories** — "Quali di queste problematiche riscontrate oggi?" — scelta multipla: La gestione delle commesse è manuale · Non disponiamo di dati affidabili · Non conosciamo lo stato delle commesse · Non conosciamo le date di consegna · Le informazioni dipendono dall'esperienza delle persone · Non conosciamo i costi di produzione · Altro
- **current_issue_other_text** — "Specifica" — testo lungo — *visible_if: `current_issue_categories` contiene "Altro"* (M16)

### 8. Miglioramenti desiderati
- **desired_improvement_categories** — "Che cosa vorreste migliorare?" — scelta multipla: Digitalizzare i processi · Automatizzare la raccolta dati · Pianificare meglio la produzione · Conoscere il carico di lavoro di macchine e operatori · Conoscere i costi di produzione · Ridurre gli scarti · Altro
- **desired_improvement_other_text** — "Specifica" — testo lungo — *visible_if: `desired_improvement_categories` contiene "Altro"* (M16)

### 9. Aspettative
- **mes_expectations_text** — "Che cosa vi aspettate dall'implementazione di un software MES come Bravo Manufacturing?" — testo lungo

### 10. Conclusione
- **was_webinar_suggested** — "È stato suggerito il webinar?" — sì/no (default: no)
- **sales_notes_text** — "Note del commerciale" — testo lungo
