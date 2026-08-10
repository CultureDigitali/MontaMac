# Contributing to MontaMac

Thanks for helping make remote drives easier to use on macOS.

## Before you start

- Search existing issues and pull requests.
- Use an issue for significant behavior or UI changes before investing in implementation.
- Report vulnerabilities privately through [SECURITY.md](SECURITY.md), never in a public issue.
- Never commit passwords, tokens, private keys, real server addresses, production logs or personal mount paths.

## Local setup

MontaMac requires macOS 15 or newer and Swift 6.

```bash
git clone https://github.com/CultureDigitali/MontaMac.git
cd MontaMac
swift test
```

Build the native application and installer with:

```bash
zsh Scripts/build-app.sh
zsh Scripts/build-pkg.sh
```

## Development workflow

1. Create a focused branch such as `feature/webdav-improvement` or `fix/mount-status`.
2. Keep commits small and describe the user-visible outcome.
3. Add or update tests for behavior changes.
4. Update all four localizations—Italian, English, French and Spanish—when copy changes.
5. Run `swift test` before opening a pull request.

Use reserved `.example` domains and synthetic credentials in tests, screenshots and documentation.

## Pull requests

A pull request should explain what changed, why it matters and how it was verified. Include screenshots for interface changes and disclose any installer, security or release impact.

By contributing, you agree that your work is licensed under the repository's [MIT License](LICENSE).
