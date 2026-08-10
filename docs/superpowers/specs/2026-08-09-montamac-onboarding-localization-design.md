# MontaMac – Usabilità, guida e localizzazione

## Obiettivo

Rendere l’app autoesplicativa al primo utilizzo e disponibile in italiano, inglese, francese e spagnolo.

## Esperienza utente

- Onboarding in tre passi: requisiti, configurazione e primo mount.
- Guida integrata con ricerca: installazione rclone/FUSE-T, creazione drive, sicurezza, problemi comuni e diagnostica.
- Tooltip per azioni tecniche, messaggi vuoti utili e pulsanti rapidi contestuali.
- Schermata Impostazioni: lingua dell’app e riapertura della guida.

## Localizzazione

- Localizzazioni native macOS: `it`, `en`, `fr`, `es`.
- Lingua di sistema come default; selezione manuale salvata nelle preferenze.
- Nessun testo rivolto all’utente resta hard-coded in SwiftUI.
- Inglese come fallback per chiavi mancanti.

## Qualità

- Test che verificano tutte le chiavi nelle quattro lingue.
- Test dell’onboarding completato e ripristino guida dalle impostazioni.
- Build e test completi prima della consegna.
