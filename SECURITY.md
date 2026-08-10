# Security Policy

## Supported version

Security updates currently target the latest MontaMac release.

| Version | Supported |
| --- | --- |
| 2.1.x | Yes |
| Earlier versions | No |

## Reporting a vulnerability

Please do not disclose vulnerabilities through a public GitHub issue.

Email [info@culturedigitali.eu](mailto:info@culturedigitali.eu) with the subject `MontaMac Security`. Include the affected version, reproduction steps and expected impact. Do not include real passwords, private keys or production connection data.

Culture Digitali Srl will acknowledge the report and coordinate remediation and disclosure.

## Distribution notice

The initial `2.1.0` package is not notarized with an Apple Developer ID. Verify the published SHA-256 checksum before installation. This limitation concerns distributor identity and Gatekeeper trust; it does not replace review of the source code or safe handling of remote-drive credentials.
