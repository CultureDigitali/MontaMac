# MontaMac 2.1.0 — Security & Stability

## Obiettivo

Rafforzare MontaMac senza interrompere il flusso normale e senza rimuovere la compatibilità FTP richiesta dall'utente. La release riduce l'esposizione locale di metadati e credenziali, impedisce operazioni pericolose sui mount e migliora il recupero dello stato dopo riavvii o errori.

## Risultati dell'audit

- `connections.json` e `activity.json` sono attualmente creati con permessi `0644` e la directory applicativa con `0755`.
- Le configurazioni rclone usano correttamente `0600`, ma possono restare sul disco dopo alcuni errori o crash.
- L'eliminazione di un profilo non elimina la relativa password dal Portachiavi.
- Il nome visibile del profilo viene usato come nome interno della sezione rclone.
- Un'app riavviata non ricostruisce lo stato dei mount già attivi e può tentare un secondo processo sullo stesso percorso.
- I percorsi locali assoluti pericolosi, incluso `/`, superano la validazione corrente.
- FTP resta non cifrato; SFTP senza `known_hosts_file` non verifica la chiave del server per impostazione predefinita.
- L'installer esegue script remoti ufficiali tramite pipe e lascia lo script temporaneo nell'Application Support.
- L'app è firmata ad-hoc, senza Hardened Runtime, Developer ID o notarizzazione; Gatekeeper la rifiuta.

## Hardening dei dati locali

- La directory `~/Library/Application Support/MontaMac` e le sue sottodirectory vengono portate a `0700`.
- `connections.json`, `activity.json` e ogni configurazione temporanea vengono portati a `0600` dopo ogni scrittura atomica.
- Le nuove password nel Portachiavi dichiarano esplicitamente `kSecAttrAccessibleWhenUnlocked`.
- La cancellazione di un profilo elimina prima la password e la configurazione temporanea; se la cancellazione dal Portachiavi fallisce, il profilo non viene rimosso silenziosamente.
- I file di configurazione rclone vengono eliminati dopo fallimento, smontaggio riuscito e pulizia di avvio quando il profilo non risulta montato.
- La password oscurata da rclone viene trattata come segreto recuperabile, non come cifratura sicura.

## Hardening delle connessioni

- Il nome interno rclone deriva dall'UUID del profilo e non dal nome inserito dall'utente.
- I nomi visibili restano liberi e non influenzano la sintassi della configurazione.
- I mount usano `--umask 077` e una cache separata per UUID sotto `~/Library/Caches/MontaMac`, protetta con `0700`.
- La cache mantiene i dati necessari alle scritture e applica limiti di età; non viene cancellata aggressivamente per evitare perdita di upload in sospeso.
- I percorsi `/`, `/System`, `/Library`, `/Applications`, `/usr`, `/bin`, `/sbin` e `/private` vengono rifiutati. I percorsi normali dell'utente restano consentiti.
- Se il percorso è già montato, MontaMac non avvia un secondo processo rclone.
- FTP resta disponibile con un avviso discreto e non modale. SFTP e WebDAV HTTPS vengono indicati come preferibili.

## Stabilità e ciclo di vita

- All'avvio, MontaMac riconcilia i profili con la tabella mount di macOS.
- Le azioni disponibili riflettono i mount già attivi anche dopo il riavvio dell'app.
- Un profilo montato, in connessione o in smontaggio non può essere eliminato.
- Il pulsante di eliminazione e il comando menu condividono la stessa regola.
- L'output rclone viene raccolto in memoria con limite massimo e oscuramento di host, utente e percorso locale; non vengono registrate password.
- Un errore nell'apertura del Finder non modifica lo stato del mount.

## Installer e distribuzione

- I download ufficiali forzano HTTPS e TLS 1.2 o superiore con fallimento esplicito sugli errori HTTP.
- Lo script temporaneo dei requisiti si autoelimina al termine.
- La build locale usa Hardened Runtime anche con firma ad-hoc.
- La firma Developer ID e la notarizzazione restano escluse perché sul Mac non è presente alcuna identità valida. La pipeline sarà predisposta per accettare identità reali in futuro senza inserirle nel codice.
- La versione finale è `2.1.0`; gli artefatti sono `MontaMac.app` e `dist/MontaMac-2.1.0.pkg`.

## Interfaccia

- Nessun nuovo popup durante il normale utilizzo.
- Nel form FTP compare un avviso compatto: il protocollo non cifra credenziali e dati.
- Diagnostica e log mostrano problemi utili senza includere segreti.
- L'avviso viene tradotto in italiano, inglese, francese e spagnolo; il resto dell'interfaccia resta invariato.

## Test e verifica

- Test dei permessi `0700/0600` su directory e file temporanei.
- Test della cancellazione credenziale/configurazione.
- Test del nome interno UUID e dell'assenza del nome visibile del profilo nella sezione rclone.
- Test dei percorsi di mount vietati e consentiti.
- Test che un mount esistente non generi un secondo avvio.
- Test delle regole di eliminazione per ogni stato.
- Test dei comandi installer rafforzati e dell'autoeliminazione dello script.
- Suite completa, build release, firma, Hardened Runtime, risorse, package payload e avvio reale.

## Limiti dichiarati

- FTP rimane intrinsecamente non cifrato.
- La firma ad-hoc non consente di superare Gatekeeper su Mac esterni.
- L'App Sandbox non viene attivata perché l'app deve montare percorsi scelti dall'utente e avviare rclone; l'adozione richiede una futura riprogettazione con helper privilegiato e distribuzione firmata.

## Riferimenti ufficiali

- Rclone password obscure: https://rclone.org/commands/rclone_obscure/
- Rclone SFTP host key validation: https://rclone.org/sftp/#host-key-validation
- Rclone FTP TLS: https://rclone.org/ftp/#tls-options
- Apple Keychain accessibility: https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility
- Apple notarization: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
