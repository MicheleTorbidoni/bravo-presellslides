# Milestone M16 — Questionario esteso: condizionali e rifiniture

## Novità nell'app

- Nella **Profilazione**, i campi di dettaglio ora compaiono **solo quando servono**: "Specifica" (ruolo Altro) appare solo scegliendo "Altro"; la "% conto terzi" solo se conto terzi = Sì; il nome del software solo se si usa un gestionale; i vari "Specifica" delle scelte multiple solo quando si seleziona "Altro".
- Un valore già inserito in un campo che poi si nasconde **viene conservato**: riattivando la condizione lo si ritrova (non viene cancellato).
- Il **"Totale persone"** si calcola automaticamente sommando i quattro conteggi (operatori, ufficio tecnico, amministrazione, altri d'ufficio) e resta **correggibile a mano**: un totale digitato manualmente vince finché non lo si **svuota**, dopodiché riprende l'auto-somma.
- I campi numerici mostrano una **validazione inline non bloccante**: interi/valuta ≥ 0, percentuali tra 0 e 100. Il messaggio non impedisce né il salvataggio né l'avanzamento.

## Cosa è stato costruito

**Config**
- `content/config/questionnaire.json`: aggiunto il marker `"autosum": [<4 conteggi>]` su `total_people_count`. Le condizioni `visible_if` erano già presenti da M15; ora vengono applicate.

**Frontend**
- `app/frontend/components/questionnaire/ExtraField.tsx`:
  - `FieldDef` esteso con `autosum?: string[]`.
  - `numericError(def, value)`: validazione leggera per integer/currency (≥ 0) e percentage (0–100). Renderizzata come `<p class="text-xs text-danger-display">` sotto il campo, con `aria-invalid`/`aria-describedby` sull'`Input`; aggiunti `min`/`max`/`step` nativi.
- `app/javascript/pages/PresaleSessions/Profiling.tsx`:
  - `isVisible(def, qual)`: valuta `visible_if` (`{field, includes}` → l'array contiene il valore; `{field, equals}` → uguaglianza). Applicato nel filtro del loop dei gruppi; i `ref` e i campi senza condizione restano sempre visibili. **Valore nascosto conservato** (non si tocca `qual`). Un gruppo che resta senza item visibili non renderizza l'`<h2>`.
  - Auto-somma: helper `findAutosum`/`sumOf`/`anyFilled`; stato `totalOverridden` (non persistito, seed dai dati salvati: un totale ≠ somma è considerato manuale); `useEffect` che ricalcola il totale da `prev` quando cambiano i conteggi e non c'è override (con guardia di uguaglianza per evitare scritture/loop e per non introdurre un `total: null` spurio); `onChange` dedicato al campo totale che accende/spegne l'override (spegne quando svuotato).

**Test**
- `content_config_test.rb`: `total_people_count` dichiara l'autosum sui 4 conteggi; ogni `visible_if` referenzia un campo esistente ed è ben formata.
- `test/system/questionnaire_conditionals_test.rb` (nuovo): comparsa/nascondimento/ritenzione dei campi condizionali; auto-somma con override che vince fino allo svuotamento; validazione inline non bloccante (e gate "Avanti" indipendente).

## Decisioni non pre-specificate nel PRD

- **Valore nascosto = conservato** (scelta dell'utente): un campo nascosto da `visible_if` mantiene il valore in `qualification_answers`; riappare se la condizione torna vera. Implementazione più semplice (basta non renderizzarlo).
- **Auto-somma via marker di config** (`autosum` in `questionnaire.json`) invece di nomi di campo hardcoded nel componente: mantiene il framework generico.
- **Ripresa dell'auto-somma**: svuotare il campo totale disattiva l'override (coerente con "finché non viene azzerato"); nessun bottone "ricalcola" dedicato.
- **Validazione non bloccante**: solo feedback visivo (`aria-invalid` + messaggio); non impedisce auto-save né "Avanti" (che resta comunque solo-criticità).

## Cosa serve dopo

La Fase 5 è completa (framework + condizionali/rifiniture). Fuori scope, per fasi future: **sync HubSpot** delle risposte (le chiavi di `qualification_answers` sono già allineate 1:1 alle proprietà) ed **esposizione** delle risposte al commerciale (debrief/recap/export).

## Scostamenti dal PRD

Nessuno. Scope di M16 rispettato: `visible_if`, auto-somma `total_people_count`, validazioni leggere. HubSpot ed esposizione a valle restano fuori (Fase 5).
