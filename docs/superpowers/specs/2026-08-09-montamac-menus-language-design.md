# Menu e lingua di MontaMac — Specifica

## Obiettivo

Aggiungere un’esperienza macOS completa con menu nativi, Impostazioni, cambio lingua immediato e copertura integrale delle stringhe dell’app.

## Menu

- **File**: Nuovo profilo, Modifica profilo, Elimina profilo.
- **Drive**: Monta, Smonta, Apri nel Finder, Aggiorna statistiche, Requisiti di sistema.
- **Visualizza**: Dashboard, Profili, Preferiti, Montati.
- **Lingua**: Italiano, English, Français, Español, con segno di spunta sulla lingua attiva.
- **Aiuto**: Guida MontaMac, Mostra introduzione, Diagnostica.
- Le azioni non valide per lo stato corrente sono disabilitate; le azioni frequenti ricevono scorciatoie da tastiera.

## Architettura

- `AppSettings` conserva la lingua scelta con `@AppStorage` e produce il `Locale` SwiftUI.
- `MontaMacApp` condivide `AppSettings` con finestra, menu e scena `Settings`.
- `DriveCommands` usa `FocusedValues` per comandare la finestra attiva senza duplicare `AppViewModel`.
- `SettingsView` permette di scegliere la lingua e mostra informazioni su versione e requisiti.
- `MainWindowView` espone azioni focalizzate per profili, drive, navigazione, guida e requisiti.

## Cambio lingua

- La lingua cambia immediatamente impostando `environment(\.locale, settings.locale)`.
- La preferenza persiste tra gli avvii.
- Le lingue supportate sono `it`, `en`, `fr`, `es`; valori sconosciuti ricadono su italiano.
- Tutte le stringhe visibili, inclusi messaggi di errore, onboarding, diagnostica, profili e requisiti, vengono incluse nei quattro file `Localizable.strings`.

## Comportamento ed errori

- I menu operano solo sulla finestra e sul profilo attualmente attivi.
- Monta/Smonta rispettano controllo requisiti e stato del drive già esistenti.
- L’eliminazione usa una conferma prima di modificare i profili salvati.
- Se nessuna finestra è focalizzata, i comandi dipendenti dal profilo restano disabilitati.

## Accessibilità

- Ogni voce usa un titolo localizzato, una scorciatoia standard e uno stato abilitato coerente.
- La scelta lingua è disponibile sia dal menu sia da Impostazioni.
- Le icone non sostituiscono mai le etichette testuali nei menu.

## Test

- Persistenza e fallback della lingua.
- Disponibilità delle quattro lingue e completezza delle chiavi obbligatorie.
- Stato abilitato dei comandi con o senza profilo selezionato.
- Build release, test completi, verifica firma ad-hoc e payload `.pkg`.
- Prova manuale di menu, scorciatoie, Impostazioni e cambio lingua senza riavvio.
