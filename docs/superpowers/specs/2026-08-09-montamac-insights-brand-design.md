# MontaMac Insights e identità visiva

## Obiettivo

Estendere MontaMac con una dashboard operativa, statistiche locali e remote, strumenti di salute del drive e un’identità visiva originale.

## Esperienza utente

- Nuova voce `Dashboard` nella sidebar, selezionata all’avvio.
- Panoramica: drive attivi, disponibilità, tempo totale di connessione, dati trasferiti, errori e grafico degli ultimi 30 giorni.
- Scheda drive: spazio remoto, numero file/cartelle, ultima scansione, velocità e cronologia sessioni.
- Pulsanti: aggiorna statistiche, verifica salute, apri Finder, monta o smonta.
- Attività recenti e notifiche locali per montaggi riusciti, errori e drive disconnessi.
- Scansioni remote avviate manualmente: nessun polling continuo su FTP/SFTP/WebDAV.

## Dati e servizi

- `ActivityStore` salva eventi e contatori non sensibili in Application Support.
- `RemoteStatisticsService` usa rclone per ottenere dimensione, conteggio e dettagli del remote; registra durata e risultato.
- `HealthCheckService` controlla rclone, cartella locale, stato di mount e raggiungibilità del remote.
- I dati aggregati sono disponibili anche per grafici e card della dashboard.
- Password e file rclone temporanei mantengono la politica già approvata: Portachiavi e permessi stretti.

## Identità visiva

- Logo ufficiale: monogramma `M` geometrico che avvolge un drive, con blu elettrico e verde acqua.
- Icona applicazione quadrata con angoli morbidi, resa in tutte le dimensioni richieste da macOS.
- Iconset UI coerente: dashboard, attività, salute, spazio, trasferimento e stato dei drive.
- Il logo viene creato come asset raster originale e integrato nel catalogo immagini dell’app.

## Qualità

- Test per aggregazione metriche, persistenza, parser output rclone e stato di salute.
- Gli errori della scansione mostrano un messaggio chiaro e non cancellano le statistiche precedenti.
- Build Release e test completi prima dell’avvio della nuova versione.
