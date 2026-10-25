# Bravo Manufacturing Pre-Sale Tool — Fase 8: Criticità sganciate dal segmento

> **Informazioni su questi file di roadmap:** questa cartella (`docs/roadmap/fase-8-criticita-sganciate-segmento/`) contiene il PRD della **Fase 8**, un incremento costruito **sopra** i milestone già rilasciati (fino a M19, Fase 7). Come le fasi precedenti è un artefatto di guida: nessun codice, configurazione o logica di runtime deve importare o dipendere da questi file. La fonte di verità è il codice.

## Cosa stiamo costruendo

Finora il segmento industriale decideva **quali** criticità si potevano presentare: il Setup mostrava solo il sottoinsieme del segmento, e per portare in call una criticità di un altro segmento serviva il pannello "Aggiungi criticità da un altro segmento" (Fase 4, M14).

Nella pratica è più ragionevole poter indicare **qualsiasi criticità per qualsiasi azienda**. Il collegamento segmento ↔ criticità (`content/config/mappings.json`) resta come **documentazione**: nell'app diventa solo un'indicazione visiva, il badge "Tipica del segmento".

Allo stesso tempo il flusso si semplifica: tutta la configurazione della presentazione avviene nella **prima** schermata, e il secondo passaggio dal Setup (Fase 6, M17) sparisce.

La Fase 8 è costruita in **un solo milestone** (M20).

## Flusso

| Prima (Fase 6) | Ora (Fase 8) |
|---|---|
| Setup "light" → Profilazione → Setup "full" → Presentazione | **Setup** → **Profilazione** → **Presentazione** |

1. **Setup sessione**: nome azienda, contatto, segmento industriale, **elenco completo delle 13 criticità** (abilitazione + ordine con trascinamento) e le caselle "Mostra l'introduzione all'inizio" / "Mostra l'hub tra le criticità", **già spuntate**.
2. **Profilazione** (Questionario A): invariata.
3. **Presentazione**: si entra direttamente, partendo dall'Intro se abilitata.

## Regole

- Qualunque segmento si scelga, l'elenco mostra **sempre tutte** le criticità.
- All'apertura **nessuna** criticità è spuntata, tranne quelle eventualmente indicate dal prospect su HubSpot (badge "Indicata dal prospect").
- Le criticità che `mappings.json` associa al segmento scelto mostrano il badge **"Tipica del segmento"**. È solo un'indicazione: non preseleziona né limita nulla.
- Cambiare segmento **non azzera** selezione e ordine, sposta solo i badge.
- Per proseguire servono un segmento e almeno una criticità abilitata.
- La profilazione non preseleziona più criticità, perché arriva dopo la scelta. Continua a personalizzare il **contenuto** delle slide (override per token) e i video di approfondimento.
- Le slide di ogni criticità si risolvono sul segmento del prospect, con la consueta riserva sulle slide condivise (`content/assets/criticalities/`). Così qualsiasi criticità funziona con qualsiasi segmento.
- Il recap pubblico segue la selezione e l'ordine dell'operatore. In coda aggiunge eventuali criticità discusse che non fanno parte della selezione.

## Fuori scope

- Nessuna modifica a `mappings.json`, ai contenuti o al Questionario B.
- La colonna `extra_criticalities` (Fase 4) resta nel database ma non è più letta né scritta.
