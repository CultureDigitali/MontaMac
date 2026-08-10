# MontaMac – Installer e prerequisiti

## Obiettivo

Distribuire MontaMac con un installer macOS e un Setup Assistito che rilevi e installi, con conferma esplicita, Homebrew, rclone e FUSE-T.

## Installer

- Un pacchetto `.pkg` installa l’app in `/Applications`.
- Il preflight controlla versione macOS, architettura e spazio libero.
- Il postinstall apre MontaMac; non installa dipendenze di rete in modo silenzioso.

## Setup Assistito

- Al primo avvio analizza Homebrew, rclone e FUSE-T.
- Mostra stato, percorso rilevato e istruzioni per ogni requisito.
- Il pulsante `Installa requisiti` richiede conferma e avvia comandi Homebrew nel Terminale dell’utente, con log leggibile.
- FUSE-T viene installato attraverso il canale Homebrew ufficiale e l’app avvisa se è richiesto un riavvio.
- Il mount resta disabilitato finché i requisiti non sono completi.

## Qualità

- Test del rilevamento requisiti con filesystem e percorsi simulati.
- Script di packaging verificabile senza privilegi amministrativi.
- Build dell’app e validazione del `.pkg` prima della consegna.
