# MontaMac Transfer, Cache and Dashboard Design

## Obiettivo

Correggere il contatore `Trasferiti`, mostrare lo spazio locale occupato dalla cache VFS, aggiungere crediti discreti nel fondo della dashboard e distribuire MontaMac `2.1.1` sul Mac e su GitHub.

## Causa del problema

`ActivityStore` sa sommare gli eventi `.transfer`, ma il codice di produzione non ne registra alcuno. La dashboard quindi mostra sempre zero anche quando rclone trasferisce dati.

## Architettura scelta

### Traffico rclone

`RcloneService` avvierà `nfsmount` con statistiche a intervalli brevi e in formato singola riga:

- `--stats 5s`
- `--stats-one-line`
- `--stats-log-level NOTICE`

Un parser isolato in `MontaMacCore` estrarrà i byte totali trasferiti dalle righe rclone, supportando byte e unità IEC/SI. `MountCoordinator` manterrà il totale della sessione per ogni profilo e pubblicherà soltanto incrementi positivi, ignorando righe duplicate, valori malformati e reset del contatore.

`AppViewModel` riceverà gli incrementi e li registrerà in `ActivityStore`. Gli eventi consecutivi dello stesso profilo verranno accorpati, evitando centinaia di righe nel file attività. Il totale della dashboard continuerà a rappresentare gli ultimi 30 giorni e si aggiornerà durante il trasferimento.

### Spazio cache

Un servizio dedicato misurerà ricorsivamente la directory cache di MontaMac usando prima la dimensione allocata su disco e, quando non disponibile, la dimensione logica. File mancanti, collegamenti simbolici e file non leggibili non bloccheranno la scansione.

`AppViewModel` aggiornerà il valore all’apertura della dashboard e quando cambiano le statistiche di trasferimento. Il valore rappresenterà la somma delle cache di tutti i profili sotto `~/Library/Caches/MontaMac`.

### Dashboard e crediti

La dashboard mostrerà cinque indicatori adattivi:

1. Drive configurati
2. Trasferiti negli ultimi 30 giorni
3. Cache temporanea locale
4. Errori
5. Sessioni

Le card useranno una griglia adattiva per evitare compressioni nelle finestre più strette. In fondo comparirà una riga pulita con logo minimo e testo localizzato: `Creato da Luigi Strazzullo per Culture Digitali Srl`, con collegamento al sito aziendale.

## Localizzazione

Le nuove etichette e descrizioni saranno disponibili in italiano, inglese, francese e spagnolo. I test di completezza includeranno le nuove chiavi.

## Errori e sicurezza

- Nessun server rclone RC e nessuna nuova porta locale.
- Nessun dato sensibile nei log o negli eventi.
- I valori non validi di rclone saranno ignorati senza interrompere il mount.
- La scansione cache resterà asincrona e non bloccherà l’interfaccia.
- Le autorizzazioni private già applicate alla cache resteranno invariate.

## Versione e distribuzione

La versione diventerà `2.1.1`, build `5`. Verranno aggiornati `Info.plist`, script del pacchetto e metadati di release. Dopo i test verranno generati app e installer, installata la nuova app in `/Applications`, rilanciata, pubblicata una branch GitHub e aperta una pull request.

## Test

- Parsing dei formati rclone e rifiuto delle righe non valide.
- Calcolo degli incrementi con duplicati e reset di sessione.
- Accorpamento degli eventi di trasferimento.
- Misura della cache con file annidati.
- Presenza delle nuove traduzioni e dei crediti nella dashboard.
- Verifica versione `2.1.1` e build `5`.
- Suite Swift completa, build release, firma, pacchetto e avvio dell’app installata.
