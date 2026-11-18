# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | Yes       |

## Reporting a Vulnerability

If you discover a security vulnerability in Bonsoir, non, please report it responsibly.

**Do not open a public issue for security vulnerabilities.**

Instead, please email the maintainer directly or use [GitHub's private vulnerability reporting](https://github.com/Naosou-3355/Bonsoirnon_maklock/security/advisories/new).

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- **Acknowledgment:** within 48 hours
- **Assessment:** within 7 days
- **Fix release:** as soon as possible, depending on severity

## Security Design

Bonsoir, non is designed with security in mind:

- **No data collection** — Bonsoir, non does not collect, transmit, or store any user data beyond local preferences
- **No network access** — the app does not make any network connections (Bluetooth is local-only for Apple Watch)
- **Keychain storage** — only a salted PBKDF2-SHA256 hash of the backup password is stored in the macOS Keychain, with an escalating lockout after 5 failed attempts
- **System blacklist** — critical system apps (Terminal, Xcode, Activity Monitor) can never be locked
- **Panic key** — emergency overlay dismissal is available in DEBUG builds only
- **Timeout failsafe** — after 60 s the overlay closes and hides the protected app, which stays locked
- **No auto-update** — Sparkle has been removed; updates are manual
