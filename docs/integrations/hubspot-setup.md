# Integrazione HubSpot ↔ App Pre-sell — Cosa attivare lato HubSpot

**A chi è rivolto:** a chi amministra l'account HubSpot di Bravo.
**Scopo del documento:** elencare in modo chiaro cosa va creato/abilitato dentro HubSpot perché l'app pre-sell possa dialogare con il CRM, così da poter valutare **se è tutto attivabile** con il piano attuale.
**Cosa NON serve fare:** scrivere codice o toccare l'app — quella parte la gestiamo noi. Qui si tratta solo di configurazione dentro HubSpot.

---

## 1. Contesto in due righe

Vogliamo collegare HubSpot all'applicazione che Loredana usa durante le call di pre-vendita, in due direzioni:

- **HubSpot → App (in ingresso):** quando un prospect prenota la call dal sito (Meeting Scheduler), l'app crea **in automatico** una sessione già pre-compilata con nome, cognome ed email, pronta per Loredana.
- **App → HubSpot (in uscita):** a fine call, l'app aggiorna **in automatico** la scheda del contatto in HubSpot con l'esito (es. quante domande sono state poste) e una nota di riepilogo.

> Una terza fase (tracciare l'apertura della pagina di recap e i video visti) è prevista più avanti e **non** è oggetto di questo documento.

---

## 2. Requisiti di piano (da confermare)

Risulta che l'account abbia **Marketing Hub Professional + Sales Hub Professional**. Con questo piano tutto quanto segue è fattibile. Due note:

- ✅ I **Workflow** (necessari per la parte in ingresso) sono inclusi in Sales/Marketing Professional.
- ℹ️ Gli **eventi comportamentali personalizzati** (utili solo alla terza fase, futura) richiederebbero Marketing **Enterprise**. Per ora **non servono**.

**Da confermare:** che il piano attivo sia effettivamente Professional (non Starter) su almeno uno tra Sales e Marketing Hub.

---

## 3. Cosa creare/attivare

### 3.1 Una "Private App" (per far comunicare l'app con HubSpot)

È il metodo ufficiale e attuale (le vecchie "API Key" sono state dismesse da HubSpot). Genera un **token** che l'app userà per leggere/scrivere dati.

**Percorso:** Impostazioni ⚙️ → Integrazioni → **Private Apps** → *Create a private app*.

**Permessi (scopes) da spuntare:**

| Scope | A cosa serve |
|---|---|
| `crm.objects.contacts.read` | Leggere i contatti |
| `crm.objects.contacts.write` | Aggiornare i contatti (esito call) |
| `crm.schemas.contacts.read` / `crm.schemas.contacts.write` | Creare/leggere le proprietà personalizzate (vedi 3.2) |
| Permessi su **Note/Engagement** (`crm.objects.notes` o equivalente nell'elenco) | Scrivere la nota di riepilogo nella timeline del contatto |

> Se in fase di test alcuni scope risultassero insufficienti, si aggiungono in un secondo momento: la private app si può modificare.

**Cosa ci serve da voi al termine:** il **token della private app** e l'**ID del portale/account HubSpot**. Vanno trasmessi in modo riservato (non via email/chat in chiaro) — il token dà accesso ai dati del CRM.

---

### 3.2 Alcune proprietà personalizzate sul Contatto (per ricevere l'esito della call)

Servono dei "campi" custom sulla scheda contatto dove l'app scriverà l'esito. Da creare in: Impostazioni → Proprietà → *Create property* (oggetto: **Contatto**).

| Nome proprietà (suggerito) | Tipo | Contenuto |
|---|---|---|
| Pre-sell — Stato | Menù a tendina / testo | Esito sessione (es. completata) |
| Pre-sell — Domande poste | Numero | Quante domande durante la call |
| Pre-sell — Segmento | Testo / menù | Segmento industriale rilevato |
| Pre-sell — Profilo operativo | Testo | Profilo emerso |
| Pre-sell — Link recap | Testo / URL | Link alla pagina di recap |
| Pre-sell — Data completamento | Data | Quando è stata chiusa la call |

> I nomi esatti li allineiamo insieme; l'importante è sapere se è possibile crearle (sì, lo è su qualsiasi piano).

---

### 3.3 Un Workflow che avvisa l'app quando arriva una prenotazione (parte in ingresso)

Quando un prospect prenota tramite il **Meeting Scheduler** del sito, vogliamo che HubSpot "chiami" l'app passandole i dati del contatto.

**Come:** un Workflow con:
- **Trigger di iscrizione:** il contatto ha prenotato un meeting (idealmente filtrato sullo specifico scheduler della pre-sell).
- **Azione:** *Send a webhook* (invio di una chiamata HTTP) verso un **URL che vi forniremo noi**, includendo: nome, cognome, email e ID del contatto.

**Note importanti:**
- L'**URL di destinazione** e un **codice segreto** (per sicurezza) ve li forniamo noi quando la parte applicativa sarà pronta. Quindi questo workflow si configura **per ultimo**.
- Allo stato attuale lo scheduler raccoglie **solo nome ed email** — va benissimo: il segmento lo chiederà Loredana a inizio call. Non serve aggiungere domande allo scheduler.

**Da confermare:** che sia possibile creare un Workflow con azione **"Send a webhook"** (è una funzione dei piani Professional).

---

### 3.4 Un ambiente di test (consigliato, per provare senza toccare i dati reali)

Per fare le prove senza sporcare il CRM di produzione:

- Creare un **Developer Account** gratuito su developers.hubspot.com.
- Da lì generare un **test account (sandbox)**: un HubSpot "vuoto" dove ricreiamo la private app, qualche contatto finto e simuliamo una prenotazione.

In alternativa si possono fare prove controllate direttamente sull'account reale con contatti di test, ma la sandbox è più sicura.

---

## 4. Checklist di fattibilità (da spuntare con chi gestisce HubSpot)

- [ ] Il piano è **Professional** (Sales e/o Marketing), non Starter.
- [ ] È possibile creare una **Private App** con gli scope della sezione 3.1.
- [ ] È possibile creare le **proprietà personalizzate** del contatto (3.2).
- [ ] È possibile creare un **Workflow** con azione **"Send a webhook"** (3.3).
- [ ] È possibile (preferibile) creare un **Developer/Sandbox account** per i test (3.4).
- [ ] Si può fornire, in modo riservato, **token private app + ID portale** quando richiesto.

---

## 5. Cosa serve a noi (riepilogo)

1. Conferma dei punti della checklist (sezione 4).
2. Quando pronti: **token della private app** + **ID portale**, trasmessi in modo sicuro.
3. Ci coordiniamo noi per fornire **URL del webhook + codice segreto** da inserire nel Workflow (sezione 3.3), che sarà l'ultimo passo.

> Ordine consigliato: prima creare private app + proprietà custom (sezioni 3.1–3.2) e l'ambiente di test (3.4); il Workflow (3.3) si finalizza quando l'app è pronta a ricevere.

---

## Appendice tecnica — Contratto inbound (lato app)

> Questa sezione descrive **cosa l'app si aspetta di ricevere**. Oggi l'integrazione è **simulata** (vedi `docs/roadmap/fase-3-hubspot-simulazione/`): l'endpoint è reale e funzionante, ma viene pilotato da un simulatore interno finché HubSpot non è collegato. Quando lo sarà, basterà puntare il Workflow "Send a webhook" a questo endpoint con lo stesso secret — nessuna modifica al codice.

**Endpoint:** `POST /integrations/hubspot/appointments`

**Corpo (flat JSON)** — l'azione *Send a webhook* del Workflow (3.3) va configurata per inviare queste chiavi. Tutte opzionali singolarmente: una prenotazione parziale crea comunque una sessione che l'operatore completa.

| Chiave | Mappata su (sessione) |
|---|---|
| `contactId` | id contatto HubSpot (per correlare la selezione criticità successiva) |
| `firstname` + `lastname` | nome contatto (uniti) |
| `company` | azienda |
| `email` | email prospect |
| `jobtitle` | ruolo prospect |
| `industry` | segmento industriale (accettato solo se è uno dei segmenti noti dell'app; altrimenti lasciato vuoto) |
| `appointmentAt` | data/ora appuntamento (ISO 8601) |
| `salesName` | nome commerciale |
| `location` | luogo / link riunione |

**Sicurezza (firma):** ogni richiesta deve includere gli header `X-HubSpot-Signature-v3` e `X-HubSpot-Request-Timestamp`. La firma è `Base64(HMAC-SHA256(secret, METHOD + URL + body + timestamp))`; il `secret` è condiviso ed è fornito all'app via la variabile d'ambiente `HUBSPOT_WEBHOOK_SECRET` (in sviluppo un valore di default). Le richieste con firma assente/errata o con timestamp più vecchio di 5 minuti vengono rifiutate con `401`.

---

## Appendice tecnica — Contratto selezione criticità (lato app)

> Seconda direzione del dialogo: dopo la prenotazione, HubSpot invia al prospect un'email con i link alle criticità del suo settore. Cliccando, il prospect valorizza una **proprietà multi-checkbox** sul contatto (vedi sotto); HubSpot notifica l'app dell'aggiornamento. L'app ritrova la sessione tramite l'`contactId` salvato all'inbound e annota le criticità come "suggerite". Anche questo è oggi **simulato**.

**Proprietà custom da creare** (oggetto Contatto, da aggiungere a quelle della sezione 3.2):

| Nome interno proprietà | Tipo | Contenuto |
|---|---|---|
| `presell_criticality_interests` | Casella di controllo multipla | Le criticità che il prospect ha indicato come più interessanti (una opzione per criticità, valore = id criticità) |

**Endpoint:** `POST /integrations/hubspot/contact_events`

**Corpo (array di eventi, forma `contact.propertyChange`)** — è la forma con cui HubSpot consegna gli eventi di variazione proprietà (subscription della Private App o azione *Send a webhook* sul cambio proprietà):

```json
[
  {
    "objectId": 12345,
    "subscriptionType": "contact.propertyChange",
    "propertyName": "presell_criticality_interests",
    "propertyValue": "3;7;8"
  }
]
```

- `objectId` = id contatto HubSpot, usato per ritrovare la sessione (la più recente di quel contatto).
- `propertyValue` = lista `;`-separata di id criticità. L'app tiene solo gli id validi, deduplica e **sostituisce** l'elenco suggerito (idempotente: ogni evento porta il valore completo della proprietà, quindi selezioni multiple e re-invii sono gestiti senza accumulo).
- Eventi di altro tipo/proprietà, contatti senza sessione e id non validi vengono **ignorati** silenziosamente.

**Sicurezza (firma):** identica all'endpoint inbound (header `X-HubSpot-Signature-v3` / `X-HubSpot-Request-Timestamp`, stesso `HUBSPOT_WEBHOOK_SECRET`).
