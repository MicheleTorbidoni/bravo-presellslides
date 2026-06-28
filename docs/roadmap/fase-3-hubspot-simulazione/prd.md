# Bravo Manufacturing Pre-Sale Tool — Fase 3: Integrazione HubSpot (simulata)

> **Informazioni su questi file di roadmap:** questa cartella (`docs/roadmap/fase-3-hubspot-simulazione/`) contiene il PRD e i prompt per-milestone della **Fase 3** dell'app, un incremento costruito **sopra** i milestone già rilasciati (fino a M10). A differenza di `_build_plan/` (lo scaffold iniziale, destinato alla cancellazione), questa cartella documenta un'evoluzione del prodotto a partire dal codice esistente. Resta comunque un artefatto di guida: nessun codice, configurazione o logica di runtime deve importare o dipendere da questi file. La fonte di verità è il codice.

## Cosa stiamo costruendo

Far nascere le sessioni pre-sales **automaticamente da una prenotazione del prospect** anziché a mano: l'app riceve i dati del contatto via webhook e crea una sessione pre-valorizzata; riceve poi le criticità che il prospect ha indicato come più interessanti e le **evidenzia** nell'hub per chi gestisce la call. Tutto guidato da un **simulatore interno** con dati placeholder, su endpoint webhook **reali** modellati sulle forme effettive di HubSpot, così da poter collegare il vero HubSpot in futuro senza cambiare il contratto.

Oggi una `PresaleSession` nasce manualmente: Loredana crea la sessione, compila i dati prospect nel Setup, fa il profiling e gestisce la call. La Fase 3 ribalta l'origine della sessione: quando il prospect prenota un appuntamento (sul sito, gestito da HubSpot), HubSpot invia all'app i dati del contatto e l'app crea **da sola** la sessione, già piena di azienda, contatto, email, ruolo, segmento industriale e data dell'appuntamento. In una seconda email (inviata da HubSpot) il prospect può cliccare quali criticità del suo settore vuole approfondire; l'app riceve quelle scelte e le annota come **criticità suggerite**, distinte da quelle che poi verranno effettivamente discusse in call. Quando Loredana apre la sessione, la trova pronta e vede subito, nell'hub, quali temi il prospect ha pre-indicato.

Non esiste ancora un HubSpot collegato né la sua struttura dati. Per questo la Fase 3 costruisce **endpoint webhook reali** (con verifica della firma) modellati sulle due modalità che HubSpot espone davvero, e un **simulatore interno** che genera contenuti placeholder e fa partire l'intero dialogo. Collegare il vero HubSpot in futuro significherà configurare un workflow e una subscription e fornire un secret — **senza toccare il contratto** né il codice degli endpoint. Lo stack è il template **Build New** (Rails 8 + React 19 via Inertia.js + Tailwind + PostgreSQL + Solid Queue); la Fase 3 riusa pesantemente le fondamenta esistenti ed è organizzata in 3 milestone incrementali (M11, M12, M13), in continuità con i precedenti.

---

### Cosa fa l'app (novità della Fase 3)

- Riceve da HubSpot, via **webhook**, una richiesta di appuntamento e **crea da sola una sessione pre-valorizzata** (azienda, contatto, email, ruolo, segmento, data appuntamento).
- Assegna automaticamente la sessione all'**operatore** che gestirà la call.
- Riceve, sempre via webhook, la **selezione delle criticità** che il prospect ha indicato come più interessanti e le registra come **suggerite** sulla sessione corretta.
- Ricava per ogni **categoria industriale** un insieme unico di criticità (il "subset di settore"), usato sia per la selezione del prospect sia per l'hub mostrato in call.
- **Evidenzia nell'hub**, con un contrassegno dedicato, le criticità pre-indicate dal prospect, senza alterare gli stati esistenti (da-fare / completata).
- Offre a chi gestisce l'app un **simulatore interno**: un clic genera dati placeholder e mette in scena l'intero dialogo App↔HubSpot (prenotazione + selezione), mostrando la sessione creata.
- Verifica la **firma** di ogni webhook in ingresso, esattamente come farebbe col vero HubSpot.

---

### Già fornito dal codice esistente (da riusare, non ri-specificare)

- **Template Build New**: autenticazione, `AppShell` e shell autenticata, design system completo, coda Solid Queue, pipeline Inertia/SSR, area `admin`, file di discovery (sitemap/robots/llms).
- **`PresaleSession`**: il modello della singola call, già con azienda, contatto, segmento, profilo operativo, criticità discusse, domande catturate, token pubblico e dati appuntamento (`appointment_at`, ecc.).
- **`ContentConfig`**: legge i contenuti statici (`criticalities.json`, `mappings.json`, slide, video) e risolve già criticità per `(segment, operational_profile)` e i contenuti verticalizzati **dentro** ogni flusso tramite override a token (`steps_for`, `video_url_for`).
- **Hub e flusso di presentazione** (`Hub.tsx`, `Present.tsx`): la pagina con l'elenco delle criticità e gli stati visivi (verde da-fare / bianco con scudo completata).
- **Pagine senza login** (`allow_unauthenticated_access`) e **pagina pubblica di recap** già esistenti dalla Fase 2.
- **Resend** già configurato per le email (in questa fase **non** usato: l'email di selezione la invierebbe HubSpot).

---

### Fuori scope (Fase 3)

- **Vera connessione HubSpot**: token della Private App, workflow e subscription configurati, property reali sul contatto. È la fase successiva; qui tutto è simulato.
- **Outbound verso HubSpot (T2)**: aggiornare la scheda del contatto a fine call e scrivere una nota nel timeline. Rimandato.
- **Invio reale dell'email di selezione** e ogni anteprima email cliccabile: l'email la manda HubSpot; l'app simula solo la *callback* della selezione (scelta: selezione random automatica).
- **Recupero dati via CRM API** (hydrate): si è scelto il payload inbound *self-contained*, quindi non serve richiamare HubSpot per completare i dati.
- **Mappatura reale `industry` → segmento**: la traduzione dal valore HubSpot ai 7 segmenti dell'app è una configurazione lato HubSpot; qui il payload porta già l'id di segmento.
- **Modifiche alla UI** prospect/hub oltre il contrassegno delle criticità suggerite; **multi-tenant**.

---

### Modello dati

Nessuna nuova entità: si **estende `PresaleSession`** con ciò che oggi non sa memorizzare.

**PresaleSession (campi aggiunti)**
- **email prospect** — l'indirizzo del contatto arrivato dalla prenotazione.
- **ruolo prospect** — la mansione indicata nel form (es. "Responsabile produzione").
- **id contatto HubSpot** — l'identificativo del contatto in HubSpot, usato per ricollegare gli eventi successivi (la selezione delle criticità) alla sessione giusta.
- **criticità suggerite** — la lista delle criticità che il prospect ha indicato come più interessanti, **distinta** da quelle effettivamente discusse in call.

Nome e Cognome della prenotazione confluiscono nel campo "nome contatto" già esistente; azienda, segmento industriale e data dell'appuntamento usano i campi già presenti. Il **profilo operativo** continua a essere prodotto dal profiling in call e, da questa fase, **non** determina più *quali* criticità compaiono nel subset (lo determina solo il segmento): incide solo sui **contenuti mostrati dentro** ciascuna criticità.

---

### Contratto di integrazione (forme reali di HubSpot)

Gli endpoint sono modellati sulle due modalità che HubSpot espone davvero, così da essere compatibili col collegamento reale.

- **Inbound — richiesta di appuntamento** (HubSpot Workflow, azione "Send a webhook", corpo *flat JSON* personalizzato): un POST che porta in un colpo solo id contatto, nome, cognome, azienda, email, ruolo, categoria industriale, data/ora appuntamento. L'app crea la sessione pre-valorizzata.
- **Selezione criticità** (evento stile `contact.propertyChange`): un POST con id contatto, nome della property e valore (lista delle criticità scelte). L'app trova la sessione tramite l'id contatto e annota le criticità suggerite.
- Ogni richiesta è **firmata** (stile `X-HubSpot-Signature-v3`) e gli endpoint **verificano la firma** con un secret condiviso, fornito come variabile d'ambiente (in sviluppo un secret fittizio; in produzione quello reale di HubSpot). Una firma non valida viene rifiutata.

---

## Milestone M11 — Inbound: sessione da prenotazione

Quando una prenotazione (simulata) arriva via webhook, l'app crea da sola una sessione pre-valorizzata e visibile nell'elenco.

### Cosa viene costruito

- Un **endpoint webhook** che riceve la richiesta di appuntamento in formato *flat JSON* e ne **verifica la firma**.
- I **nuovi campi** sulla scheda della sessione (email prospect, ruolo prospect, id contatto HubSpot, criticità suggerite).
- La **creazione automatica della sessione** con tutti i dati mappati (nome+cognome nel contatto, azienda, email, ruolo, segmento, data appuntamento) e l'assegnazione a un **operatore** predefinito.
- Aggiornamento della documentazione di integrazione col contratto inbound.

### Cosa la milestone M11 esplicitamente NON include

- La selezione delle criticità e il subset per-segmento (M12).
- Il contrassegno nell'hub e il simulatore (M13): in M11 la sessione si crea inviando un payload all'endpoint (via test o richiesta manuale).

### Done when

Inviando all'endpoint un payload firmato di prenotazione, compare nell'elenco sessioni una nuova `PresaleSession` con dati prospect e appuntamento già valorizzati; una firma errata o assente viene rifiutata.

---

## Milestone M12 — Subset per-segmento + selezione criticità

L'app sa quali criticità competono a ciascuna categoria industriale e registra quelle che il prospect ha indicato come più interessanti.

### Cosa viene costruito

- Il **subset di criticità per segmento**: un insieme unico per categoria industriale (unione delle criticità rilevanti per quel settore), che diventa la fonte usata sia per la selezione del prospect sia per l'hub in call.
- L'allineamento dei punti dell'app che oggi mostrano il subset (hub, schermata risultato, pagina pubblica di recap) al nuovo criterio "per segmento".
- Un **secondo endpoint webhook** che riceve la selezione del prospect (evento stile property-change), trova la sessione tramite l'id contatto e vi annota le **criticità suggerite**, ignorando contatti/eventi non riconosciuti e gestendo selezioni multiple in modo ripetibile.

### Cosa la milestone M12 esplicitamente NON include

- Il simulatore interno e il contrassegno visivo nell'hub (M13).

### Done when

Inviando un evento di selezione firmato, le criticità indicate vengono annotate come "suggerite" sulla sessione correlata; l'hub e il recap mostrano un subset di criticità coerente, determinato dalla sola categoria industriale.

---

## Milestone M13 — Simulatore + evidenza nell'hub

Un clic mette in scena l'intero dialogo App↔HubSpot e, nell'hub, le criticità pre-indicate dal prospect compaiono contrassegnate.

### Cosa viene costruito

- Un **generatore di dati placeholder** (nomi, aziende, ruoli, segmento, appuntamento, id contatto) senza dipendenze nuove.
- Una **pagina nell'area admin** con un pulsante "Simula prenotazione da HubSpot" che genera i dati, firma e invia ai due endpoint reali la prenotazione e una **selezione casuale** di criticità, poi mostra la sessione creata.
- Il **contrassegno nell'hub** sulle pillole delle criticità suggerite, compatibile con gli stati esistenti (una pillola può essere insieme suggerita e completata).

### Cosa la milestone M13 esplicitamente NON include

- Outbound verso HubSpot (T2), invio email reale, anteprima email cliccabile.

### Done when

Da `/admin/hubspot-simulator` un clic crea una sessione pre-valorizzata, vi applica criticità suggerite casuali e nell'hub le pillole corrispondenti mostrano il contrassegno, mantenendo lo stato "completato" su quelle eventualmente già fatte. Suite di test, type-check e linting verdi; flusso verificato nel browser con screenshot desktop e mobile.
