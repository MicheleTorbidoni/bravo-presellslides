# Milestone M15 — Questionario esteso: framework

## Novità nell'app

- La schermata di **Profilazione** ora mostra, oltre alle 5 domande dell'albero decisionale, un **questionario di qualificazione commerciale** (~24 domande) organizzato in **gruppi semantici** (Interlocutore, Azienda, Produzione & macchine, Gestione & software, Motivazione, Obiettivi, Criticità attuali, Miglioramenti, Aspettative, Conclusione).
- Le **domande-criticità** (quelle che guidano le slide) sono **interlacciate** nei gruppi pertinenti e rese **visivamente distinte** con una card a sfondo accent tenue; le domande extra hanno stile neutro.
- Le domande extra usano **tipi di campo nuovi**: scelta multipla (checkbox), testo, numero intero, valuta (€), percentuale (%), sì/no, testo lungo.
- Un **toggle "Mostra solo domande per le criticità"** in testa nasconde tutte le extra e lascia vedere solo le domande-criticità (utile per capire cosa manca prima di procedere).
- Le risposte si **salvano automaticamente** durante la compilazione e si **ripristinano** ricaricando la pagina.
- Il pulsante **"Avanti"** resta legato **solo** alle domande-criticità sul percorso attivo: le domande extra non bloccano mai l'avanzamento.

## Cosa è stato costruito

**Backend**
- Migrazione `20260703200202_add_qualification_answers_to_presale_sessions`: colonna `qualification_answers` (jsonb, `null: false, default: {}`) su `presale_sessions`.
- `content/config/questionnaire.json` (nuovo): 10 gruppi con item = `{ ref: "d?" }` (domande-criticità) o campo extra inline (`field`, `label`, `type`, `options?`, `visible_if?`). I `visible_if` sono già scritti ma **non** ancora applicati (M16). Popolato dall'Appendice A del PRD.
- `ContentConfig#questionnaire` (`load_config("questionnaire")`) e `ContentConfig#questionnaire_field_keys` (`{ multi_select: [...], scalar: [...] }`, esclude i `ref`).
- `PresaleSessionsController#profiling`: passa le prop `questionnaire` e `qualificationAnswers`. `#session_params`: permette `qualification_answers` ristretto alle chiavi note del questionario (config-driven via `questionnaire_field_keys`, multi_select come array, resto scalari — nessun `permit!`). L'action `update` resta `head :ok` (auto-save via `apiPatch`/fetch).

**Frontend**
- `app/frontend/components/ui/textarea.tsx` (nuovo primitivo): wrapper su `<textarea>` con `form-control form-control-textarea` (classe CSS già esistente). Documentato in `FormsSection` del design system.
- `app/frontend/components/questionnaire/ExtraField.tsx` (nuovo): rende un campo extra per tipo (multi_select→Checkbox, boolean→Radio Sì/No, testo→Input, integer/currency/percentage→Input number con adornment, textarea→Textarea).
- `app/javascript/pages/PresaleSessions/Profiling.tsx` (riscritto): itera i gruppi; i `ref` risolvono la domanda dell'albero (fieldset con radio + disabilitazione a cascata, avvolta in card accent), i campi inline rendono `ExtraField` (card neutra). Stato `answers` (criticità, ricostruito da `operational_profile`), `qual` (extra, da `qualificationAnswers`), `onlyCriticality` (toggle). Auto-save debounced 400ms di `{ operational_profile, qualification_answers }`; `finish()` salva e naviga.

**Logica token invariata**: `enabledIds`, `walkProfile` e il gate "Avanti" sono identici a prima e dipendono solo da `answers`. Nuovo helper `answersFromProfile` per il ripristino.

**Test**
- `content_config_test.rb`: il questionario carica; ogni `ref` esiste nell'albero ed è referenziato una volta; chiavi campo uniche; multi_select con opzioni; `questionnaire_field_keys` separa correttamente ed esclude i ref.
- `presale_sessions_controller_test.rb`: `update` persiste `qualification_answers` (scalari + array) e ignora chiavi sconosciute.
- `test/system/questionnaire_framework_test.rb` (nuovo): layout a gruppi, compilazione campi extra vari, auto-save + ripristino al reload, toggle "solo criticità", gate "Avanti" solo-criticità; screenshot desktop + mobile.
- Aggiornato `profiling_all_at_once_test.rb`: il frammento per la domanda IoT (d2) è ora `"Avete macchine"` perché la stringa "IoT" compare anche in un'opzione del campo `contact_reason_categories`.

## Decisioni non pre-specificate nel PRD

- **Permit config-driven**: `qualification_answers` è permesso solo sulle chiavi note del questionario (no `permit!`, no mass-assignment arbitrario), derivandole da `ContentConfig.questionnaire_field_keys`.
- **Ripristino risposte-criticità**: ricostruite dal prefisso di `operational_profile` (auto-salvato in continuo) via `answersFromProfile`, non da uno storage dedicato. *Limitazione nota*: risposte-criticità date "fuori ordine" (prima di una domanda a monte non ancora risposta) non stanno nel prefisso e non si ripristinano — impatto trascurabile (5 radio); le risposte extra (il vero valore da preservare) si ripristinano sempre e fedelmente.
- **`Textarea` documentato in `FormsSection`** invece che in una sezione nuova del design system (più idiomatico; la classe CSS `form-control-textarea` esisteva già).
- Adornment valuta/percentuale reso con uno `<span>` assoluto sovrapposto all'`Input` (pl-7 / pr-8).

## Cosa serve a M16

- La forma di `questionnaire.json` (item con `field`/`type`/`options`/`visible_if`, e `ref`) e la resa dei campi vivono in `ExtraField.tsx`; lo stato delle risposte extra è in `qual` dentro `Profiling.tsx`.
- I `visible_if` sono **già scritti** in `questionnaire.json` (forme: `{ field, includes }` per i multi_select "Altro", `{ field, equals: true }` per i boolean) e nei tipi di `ExtraField` (`VisibleIf`), ma **non applicati**: M16 deve implementare la logica hide/show, l'auto-somma di `total_people_count` e le validazioni leggere.

## Scostamenti dal PRD

Nessuno. Scope di M15 rispettato: `visible_if`, auto-somma e validazioni restano fuori (M16); i campi condizionali sono per ora sempre visibili, come previsto.
