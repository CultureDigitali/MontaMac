# MontaMac — Crediti e primo rilascio GitHub

## Obiettivo

Pubblicare MontaMac come progetto open-source di Culture Digitali Srl, attribuendo chiaramente ideazione e sviluppo a Luigi Strazzullo e impedendo che dati locali, credenziali o artefatti interni entrino nel repository o nella release.

## Crediti nell'app

Le Impostazioni includono una sezione `Crediti` coerente con la UI esistente. La vista mostra:

- logo MontaMac;
- `Creato da Luigi Strazzullo per Culture Digitali Srl`;
- Luigi Strazzullo come fondatore e amministratore di Culture Digitali Srl, imprenditore e consulente digitale;
- sito `https://culturedigitali.eu/`;
- email aziendale `info@culturedigitali.eu`;
- telefono aziendale `+39 081 180 88 248`;
- sede `Via Coroglio 57D, 80124 Napoli`;
- partita IVA `IT09465861210`.

Sito, email e telefono sono azioni cliccabili. Non vengono inseriti recapiti personali o informazioni non presenti su fonti ufficiali pubbliche. Tutto il testo viene tradotto in italiano, inglese, francese e spagnolo.

## Repository pubblico

Il repository previsto è `CultureDigitali/MontaMac`, pubblico, con branch principale `main` e licenza MIT intestata a `Culture Digitali Srl` per l'anno 2026.

Il repository contiene solo sorgenti, test, asset necessari, script di build, documentazione e file installer sorgenti. Non contiene bundle `.app`, directory `.build`, pacchetti `.pkg`, file `.superpowers`, dati utente, configurazioni rclone, log, token, chiavi, certificati o file di ambiente.

La documentazione pubblica comprende:

- `README.md` con caratteristiche, requisiti, installazione, build, sicurezza, crediti e limitazioni;
- `LICENSE` MIT;
- `SECURITY.md` con canale responsabile per segnalazioni;
- `CHANGELOG.md` con la release iniziale `2.1.0`;
- note della release GitHub in italiano e inglese.

## Protezione dei dati sensibili

`.gitignore` esclude almeno:

- `.build/`, `MontaMac.app/`, `dist/`;
- `.superpowers/`, `.DS_Store` e stato locale degli IDE;
- `.env*`, file di credenziali, chiavi, certificati e profili di firma;
- `connections.json`, `activity.json`, configurazioni `rclone/*.conf` e log locali.

Prima del primo commit vengono controllati sia i file presenti sia l'esatto insieme che Git intende tracciare. La scansione cerca token, password, chiavi private, URL con credenziali, percorsi utente reali e dati di connessioni. I valori fittizi nei test restano ammessi solo se evidentemente sintetici, come domini `.example` e password letterali di test.

## Release GitHub 2.1.0

Il primo rilascio usa il tag annotato `v2.1.0`. La GitHub Release allega:

- `MontaMac-2.1.0.pkg`;
- file checksum SHA-256;
- note di rilascio con funzionalità, requisiti, controlli di sicurezza e limitazioni.

Il pacchetto non viene versionato nel repository. Poiché manca una firma Developer ID Installer e la notarizzazione Apple, viene dichiarato chiaramente come build non notarizzata che può generare un avviso Gatekeeper. Non viene presentato come pacchetto di distribuzione Apple verificato.

## Processo di pubblicazione

1. Implementare e testare la sezione Crediti.
2. Completare documentazione, licenza ed esclusioni.
3. Eseguire test Swift, build release e verifica del pacchetto.
4. Generare checksum e scansione anti-segreto sull'insieme tracciato.
5. Inizializzare Git con branch `main` e creare un commit intenzionale.
6. Creare il repository pubblico `CultureDigitali/MontaMac`.
7. Spingere `main`, creare il tag `v2.1.0` e pubblicare la release con gli allegati.

L'autenticazione GitHub viene effettuata al momento della pubblicazione. Il token `gh` locale attualmente configurato non è valido e non viene mai copiato nel progetto.

## Verifica

- test automatico della presenza delle traduzioni dei crediti;
- suite `swift test` completa;
- build e verifica firma locale con Hardened Runtime;
- controllo del contenuto del pacchetto e della versione `2.1.0`;
- ispezione `git status`, `git ls-files` e scansione anti-segreto prima del push;
- verifica finale del repository pubblico, del tag, degli allegati e dei checksum.

## Fonti pubbliche

- Culture Digitali Srl: https://culturedigitali.eu/
- Profilo Luigi Strazzullo: https://culturedigitali.eu/notizie/luigi-strazzullo-e-levoluzione-della-programmazione/
