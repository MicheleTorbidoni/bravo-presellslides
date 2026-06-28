# Milestone 12 — Subset per-segmento + selezione criticità

Stai entrando in plan mode per pianificare e poi costruire il milestone 12 di questo progetto (Fase 3). Dipende da M11 (campi nuovi su `PresaleSession`, in particolare l'id contatto HubSpot e le criticità suggerite).

## Contesto

- Leggi `@docs/roadmap/fase-3-hubspot-simulazione/prd.md` per il contesto della Fase 3: scope, modello dati, contratto di integrazione.
- Leggi il log di M11 — `@docs/roadmap/fase-3-hubspot-simulazione/milestones/11-*/milestone-log.md` — per i campi aggiunti e il pattern degli endpoint/firma già introdotti.
- Riusa: `ContentConfig` (`criticalities`, `mappings`, `criticalities_for`) e i suoi attuali chiamanti del subset — `present` e `result` in `PresaleSessionsController`, e `PublicRecapsController`. Il subset passa da `(segment, operational_profile)` a **solo segment** (unione dei mapping del segmento); il profilo operativo resta usato per i contenuti **dentro** ogni flusso (`steps_for`/`video_url_for`), invariato.
- Contratto selezione (evento stile `contact.propertyChange`, `propertyValue` con id criticità `;`-separati): dettagli nel PRD.

## Il tuo compito

1. Pianifica l'implementazione **solo** del milestone 12 come definito nel PRD: risolutore del subset per-segmento e adeguamento dei chiamanti esistenti; endpoint webhook della selezione che correla la sessione via id contatto HubSpot e scrive le criticità suggerite in modo idempotente (selezioni multiple, ignora ignoti). Non costruire simulatore né badge UI: sono M13.
2. Dopo che l'utente ha confermato il piano, costruisci solo ciò che rientra nello scope del milestone 12.
3. Verifica il tuo lavoro rispetto ai criteri "Done when" del milestone 12 nel PRD (evento firmato → criticità suggerite annotate sulla sessione corretta; hub/recap coerenti col subset per-segmento). Aggiungi/aggiorna i test di `ContentConfig` e dei controller toccati.
4. Al completamento, scrivi un `milestone-log.md` in questa cartella (`docs/roadmap/fase-3-hubspot-simulazione/milestones/12-subset-selezione-criticita/milestone-log.md`), con `## Novità nell'app` in cima (bullet orientati all'utente) e poi le sezioni di dettaglio implementativo (cosa è stato costruito, decisioni non pre-specificate, cosa serve al milestone successivo, scostamenti dal PRD).

Fammi qualsiasi domanda di chiarimento usando lo strumento AskUserQuestion per definire il piano di implementazione di questo milestone.
