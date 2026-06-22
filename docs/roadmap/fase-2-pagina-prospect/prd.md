# Bravo Manufacturing Pre-Sale Tool — Fase 2: Pagina prospect

> **Informazioni su questi file di roadmap:** questa cartella (`docs/roadmap/fase-2-pagina-prospect/`) contiene il PRD e i prompt per-milestone della **Fase 2** dell'app, un incremento costruito **sopra** i 7 milestone iniziali già rilasciati. A differenza di `_build_plan/` (lo scaffold iniziale, destinato alla cancellazione), questa cartella documenta un'evoluzione del prodotto a partire dal codice esistente. Resta comunque un artefatto di guida: nessun codice, configurazione o logica di runtime deve importare o dipendere da questi file. La fonte di verità è il codice.

## Cosa stiamo costruendo

Una pagina web personalizzata e privata — accessibile tramite **link univoco, senza login** — che Bravo Manufacturing invia al prospect dopo la call. Raccoglie in modo strutturato il riepilogo dell'incontro (azienda, contatto, temi affrontati, punti emersi) e consente al prospect di rivedere i **video di approfondimento del proprio contesto operativo**: le criticità discusse in evidenza, più le altre del subset, con contenuti video verticalizzati per segmento industriale e profilo operativo.

Oggi, a fine call, l'app invia un'email di recap (Milestone 6) che contiene il riepilogo come testo e i link ai video come URL nel corpo. La Fase 2 sposta quei contenuti su una pagina dedicata: l'email diventa un semplice aggancio ("Apri il tuo riepilogo"), mentre la pagina offre un'esperienza strutturata, brandizzata e con i video riproducibili direttamente, senza che il prospect debba tornare continuamente all'email.

Il prospect non si autentica: il framework (template **Build New**, Rails 8 + React 19 via Inertia.js + Tailwind + PostgreSQL) non obbliga al login — ogni superficie può essere resa pubblica. L'accesso è protetto da un **token univoco e non indovinabile** incluso nel link, coerente con il fatto che l'identificazione del contatto avviene già a monte (CRM). La Fase 2 riusa pesantemente le fondamenta esistenti ed è organizzata in 2 milestone incrementali (M8, M9), in continuità con i 7 precedenti.

---

### Cosa fa l'app (novità della Fase 2)

- Genera, all'invio del recap, un **link univoco** verso una pagina personalizzata del prospect.
- Mostra al prospect una **pagina pubblica senza login**, intestata con il **nome dell'azienda e del contatto**.
- Presenta in modo **strutturato il riepilogo della call**: i **temi affrontati** (criticità discusse) e i **punti emersi** (le domande catturate durante l'incontro).
- Permette al prospect di **guardare i video di approfondimento direttamente in pagina**, senza aprire link esterni.
- Mostra le **criticità discusse in evidenza** e le **altre criticità del subset** del prospect come approfondimenti correlati esplorabili.
- Adatta i video al **contesto del prospect** (segmento industriale × profilo operativo): a parità di criticità, il video più pertinente al suo caso.
- Trasforma l'**email di recap** in una cover breve con un bottone verso la pagina.
- Consente all'operatore di **vedere e copiare il link** della pagina dal debrief e dall'archivio.
- La pagina è **responsive**: pensata per essere aperta dal prospect anche da mobile/tablet.

---

### Già fornito dal codice esistente (da riusare, non ri-specificare)

- **Template Build New**: autenticazione, `AppShell` e shell autenticata, design system completo, coda Solid Queue, pipeline Inertia/SSR, file di discovery (sitemap/robots/llms).
- **Pagine pubbliche senza login**: il meccanismo `allow_unauthenticated_access` consente a un controller di non richiedere autenticazione — nessun account va creato per il prospect.
- **Invio email**: `PresaleRecapMailer` e l'infrastruttura recap del Milestone 6 (Resend in produzione, anteprime in sviluppo).
- **Risoluzione video per contesto**: `ContentConfig.video_url_for` risolve già il video più specifico per una criticità con la catena segmento+token → token condiviso → segmento → default. La verticalizzazione video per segmento × profilo è quindi già supportata a livello di backbone.
- **Dati del recap**: il debrief (Milestone 6) produce già azienda, contatto, segmento/profilo, criticità discusse (con label), domande catturate e il corpo recap pre-composto.
- **Configurazione contenuti**: `videos.json` (varianti video), `criticalities.json`, `mappings.json` — i contenuti si editano via file + re-deploy, senza pannello di amministrazione.

---

### Fuori scope (Fase 2)

- **Integrazione HubSpot** (salvataggio/tracciatura nel CRM) — evoluzione futura.
- **Analytics sulla pagina** (visite, click, tempo di visione dei video) — non in v1.
- **Scadenza del token o accesso con PIN** — il link non scade in v1; l'identificazione avviene a monte.
- **Login o account per il prospect** — l'accesso è solo via token nel link.
- **Interazioni del prospect sulla pagina** (form, commenti, domande di ritorno, prenotazioni) — la pagina è di sola consultazione.
- **Download, versione PDF, allegati** della pagina.
- **Self-hosting o upload dei video dall'app** — i video sono ospitati su YouTube/Vimeo (unlisted) e referenziati per URL.
- **Selezione per-domanda** di cosa mostrare: tutte le domande catturate diventano "punti emersi" (l'operatore le ripulisce nel debrief/archivio, come già oggi).
- **Multilingua** — solo italiano.
- **Rigenerazione/revoca del token** dall'interno — in v1 il link è visibile e copiabile, ma non rigenerabile.

---

### Modello dati

La Fase 2 non introduce nuove entità. Aggiunge un campo alla sessione esistente.

**Sessione di pre-sale (`PresaleSession`, esistente)** — il record della call.
- *(campi esistenti: azienda, contatto, segmento, profilo operativo, criticità discusse, domande catturate, stato, date — invariati)*
- **token pubblico** — una stringa univoca e non indovinabile che identifica la pagina pubblica del prospect. Viene generata quando il recap viene inviato per la prima volta e resta stabile (non scade, non viene rigenerata in v1). È ciò che rende il link impossibile da indovinare pur essendo la pagina pubblica.

I contenuti video restano nei **file di configurazione** (`videos.json`), arricchiti con più varianti per criticità (per segmento e per token decisionale). Non sono dati di database.

---

## Milestone 8 — Pagina prospect pubblica & link nel recap

Consegna la pagina pubblica personalizzata e la trasforma nel cuore del recap: l'email smette di contenere il riepilogo testuale e diventa un aggancio alla pagina.

### Cosa viene costruito

- Alla **prima emissione del recap**, la sessione riceve un **token pubblico** e quindi un link univoco.
- Una **pagina pubblica accessibile senza login** tramite quel link, intestata con **nome azienda + nome contatto** del prospect.
- Il **riepilogo strutturato** della call sulla pagina: i **temi affrontati** (le criticità discusse) e i **punti emersi** (le domande catturate durante l'incontro), in sezioni leggibili.
- I **video** del contesto compaiono in questa milestone come **elenco di link semplici** alle criticità (l'embedding riproducibile in pagina arriva in M9), così la pagina è già provabile end-to-end.
- L'**email di recap** diventa una **cover breve** (saluto + poche righe) con un **bottone "Apri il tuo riepilogo"** che porta alla pagina.
- L'operatore **vede e copia il link** della pagina dal debrief e dalla vista dettaglio dell'archivio.
- La pagina è **responsive** (desktop, tablet, mobile) ed è **esclusa dall'indicizzazione**: non compare in sitemap, è bloccata in robots e marcata come non indicizzabile.

### Cosa il milestone 8 NON include

- L'**embedding e la riproduzione dei video in pagina** e l'esplorazione del resto del subset (arrivano in M9): qui i video sono link.
- La **rigenerazione/revoca** del link, la **scadenza** o il **PIN**.
- Qualsiasi **analytics** sulle visite alla pagina.
- Interazioni del prospect (form, commenti).

### Fatto quando

Inviando il recap di una sessione si genera un link univoco; aprendo quel link in un browser **senza essere loggati** si vede la pagina personalizzata con azienda, contatto, temi affrontati e punti emersi; l'email ricevuta è una cover breve con il bottone verso la pagina; l'operatore ritrova e copia lo stesso link dal debrief/archivio.

---

## Milestone 9 — Video di approfondimento nella pagina

Completa l'esperienza: i video diventano riproducibili direttamente in pagina e contestualizzati al prospect, con l'esplorazione dell'intero subset.

### Cosa viene costruito

- Per ogni criticità del subset del prospect, il **video di approfondimento embeddato e riproducibile in pagina** (YouTube/Vimeo unlisted), senza aprire link esterni.
- Le **criticità discusse** sono mostrate **in evidenza**; le **altre criticità del subset** risolto compaiono come **approfondimenti correlati** che il prospect può esplorare.
- Il video mostrato è quello **più pertinente al contesto** del prospect: a parità di criticità, la variante che corrisponde al suo segmento industriale e al suo profilo operativo.
- Arricchimento di `videos.json` con le **varianti** necessarie (per segmento e per token decisionale), sfruttando la risoluzione già esistente.

### Cosa il milestone 9 NON include

- Self-hosting/upload dei video, capitoli/trascrizioni, sottotitoli.
- Analytics di visione (quali video, per quanto).
- Raccomandazioni dinamiche oltre il subset risolto del prospect.

### Fatto quando

Aprendo la pagina del prospect, le criticità discusse appaiono in evidenza con il **video corretto per il suo contesto** riprodotto direttamente in pagina, e le altre criticità del subset sono esplorabili con i rispettivi video; cambiando segmento/profilo della sessione, la pagina mostra le varianti video corrispondenti.
