# MontaMac 2.0.1 — Apertura Finder dopo il mount

## Obiettivo

Rendere immediatamente visibile il contenuto del drive dopo un mount riuscito, evitando che l'utente cerchi nella cartella sbagliata o visualizzi una finestra Finder non aggiornata.

## Comportamento

- MontaMac continua a considerare riuscito il mount solo dopo la conferma di macOS.
- Dopo tale conferma apre automaticamente nel Finder il percorso locale configurato.
- Il log registra il percorso aperto senza includere credenziali o dati riservati.
- Il comando manuale `Apri nel Finder` rimane disponibile.
- Se il mount fallisce, Finder non viene aperto.
- Un eventuale errore nell'apertura di Finder non modifica lo stato del mount: viene registrato come avviso separato.

## Architettura

L'apertura della cartella resta responsabilità del livello applicativo, non del motore rclone. `AppViewModel` reagisce allo stato finale `.mounted`, registra l'attività e richiede a un componente dedicato di aprire il percorso. Il componente usa `NSWorkspace` ed espone un'interfaccia iniettabile per consentire test deterministici.

## Test

- Un mount riuscito richiede l'apertura del percorso configurato una sola volta.
- Un mount fallito non apre Finder.
- Il percorso passato al componente coincide esattamente con quello del profilo.
- La suite completa esistente deve restare verde.

## Release

Aggiornamento della versione a `2.0.1`, rigenerazione di `MontaMac.app` e `dist/MontaMac-2.0.1.pkg`, verifica firma locale, risorse multilingua, logo e script installer.
