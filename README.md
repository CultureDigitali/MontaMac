# MontaMac 2.1.0

MontaMac is a native macOS application for mounting FTP, SFTP and WebDAV remote drives directly in Finder through rclone and FUSE-T.

> Italiano: MontaMac permette di salvare, organizzare e montare drive remoti nel Finder con profili, preferiti, statistiche e diagnostica integrate.

## Features

- FTP, SFTP and WebDAV HTTPS profiles
- Finder integration and automatic folder opening
- Favorites, groups, search and mounted-drive filters
- Credentials stored in macOS Keychain
- Per-profile private rclone configuration and VFS cache
- Activity dashboard, mounted-folder statistics and diagnostics
- Italian, English, French and Spanish interface
- Automatic requirement check for rclone and FUSE-T

## Requirements

- macOS 15 or newer
- [rclone](https://rclone.org/)
- [FUSE-T](https://www.fuse-t.org/)

MontaMac checks these requirements on first launch and offers an installation command only after user confirmation.

## Build from source

```bash
swift test
zsh Scripts/build-app.sh
zsh Scripts/build-pkg.sh
```

The package script creates `dist/MontaMac-2.1.0.pkg`.

## Security

- Passwords are never stored in profile JSON files.
- Application data uses private `0700/0600` permissions.
- Sensitive rclone output is redacted from in-memory logs.
- Dangerous system mount paths are rejected.
- FTP remains available for compatibility but does not encrypt credentials or data; prefer SFTP or WebDAV HTTPS.

The public `2.1.0` package is locally signed with Hardened Runtime but is not notarized with Apple Developer ID. macOS Gatekeeper may therefore display a warning. See [SECURITY.md](SECURITY.md) for responsible disclosure.

## Credits

Created by **Luigi Strazzullo** for **Culture Digitali Srl**.

- Website: [culturedigitali.eu](https://culturedigitali.eu/)
- Email: [info@culturedigitali.eu](mailto:info@culturedigitali.eu)
- Phone: +39 081 180 88 248
- Office: Via Coroglio 57D, 80124 Napoli, Italy
- VAT: IT09465861210

## License

MontaMac is released under the [MIT License](LICENSE). Copyright © 2026 Culture Digitali Srl.
