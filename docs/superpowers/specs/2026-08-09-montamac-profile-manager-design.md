# Gestore Profili MontaMac — Specifica

## Obiettivo

Rendere ogni connessione salvata un profilo richiamabile rapidamente, con cartelle, preferiti, ricerca e azioni di montaggio immediate.

## Esperienza utente

- Nuova sezione laterale **Profili** con ricerca, filtri `Tutti`, `Preferiti`, `Montati` e cartelle personalizzate.
- Ogni riga mostra nome, protocollo, stato e ultimo utilizzo; azione rapida Monta/Smonta e stella preferito.
- Un doppio clic sul profilo monta il drive quando è smontato; quando è montato apre il dettaglio.
- L’editor connessione permette di scegliere una cartella del profilo e attivare il preferito.
- Il dashboard mostra i preferiti come scorciatoie di montaggio.

## Dati e compatibilità

- `RemoteConnection` ottiene `profileGroup: String`, `isFavorite: Bool` e `lastUsedAt: Date?`.
- I dati esistenti restano leggibili: cartella `Senza cartella`, preferito `false`, ultimo utilizzo `nil`.
- Le credenziali restano nel Portachiavi e non vengono duplicate nei profili.
- Cartelle e ordine derivano dalle connessioni salvate: nessun archivio aggiuntivo da sincronizzare.

## Logica

- `ProfileFilter` produce l’elenco filtrato; la ricerca confronta nome, host, protocollo e cartella senza distinzione maiuscole/minuscole.
- Montaggio riuscito aggiorna `lastUsedAt`, salva il profilo e aggiorna la sezione Profili.
- L’eliminazione di un profilo rimuove solo la configurazione; non cancella la cartella locale né le credenziali senza un’esplicita funzione futura.
- I filtri non eseguono operazioni sulla rete; un montaggio rimane soggetto al controllo requisiti già presente.

## Interfacce

- `ProfileFilter` nel core: selezione, filtro e ordinamento dei profili.
- `AppViewModel`: ricerca, filtro corrente, gruppi disponibili, toggle preferito, selezione e azione rapida.
- `ProfileManagerView`: pannello laterale per filtri/cartelle e lista profili con azioni accessibili.

## Test

- Decodifica retrocompatibile dei file `connections.json` esistenti.
- Filtri preferiti, montati, ricerca e ordinamento per ultimo utilizzo.
- Aggiornamento di `lastUsedAt` dopo un montaggio riuscito.
- Build, test unitari, firma ad-hoc del bundle e verifica del payload `.pkg`.

## Esclusioni

- Nessuna connessione automatica all’avvio.
- Nessuna importazione/esportazione dei profili in questa fase.
- Nessuna modifica a credenziali o requisiti di sistema.
