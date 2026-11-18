# Contributing to Bonsoir, non

Thanks for your interest in contributing to Bonsoir, non! Here's how to get started.

## Development Setup

### Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+
- Swift 5.9+

### Building from Source

```bash
git clone https://github.com/Naosou-3355/Bonsoirnon_maklock.git
cd Bonsoirnon_maklock
open MakLock.xcodeproj
```

Build and run with `Cmd+R` in Xcode. The app runs as a menu bar application (no Dock icon).

## Project Structure

```
MakLock/
  App/        - Entry point, AppDelegate, AppState
  Core/       - Services, Managers, Storage (no UI)
  UI/         - Design system, Components, Views
  Models/     - Data models (Codable structs)
  Resources/  - Assets, Info.plist, Entitlements
```

## Code Style

- Follow [Apple's API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- PascalCase for types, camelCase for properties and methods
- All public API must have documentation comments
- SwiftUI for UI, AppKit bridging where needed (NSWindow, NSStatusItem)

## Git Conventions

- Branch naming: `feature/description`, `fix/description`, `setup/description`
- Commit messages: imperative mood, English, under 72 characters
- One logical change per commit

## Safety Protocol

Bonsoir, non includes safety mechanisms to prevent locking yourself out during development:

- **Panic key (DEBUG only):** `Cmd+Option+Shift+Control+U` dismisses all overlays instantly
- **System blacklist:** Terminal, Xcode, Activity Monitor, and other dev tools can never be locked
- **Dev mode:** In DEBUG builds, overlays auto-dismiss after 25 seconds and include a Skip button
- **Timeout failsafe:** After 60 seconds the overlay closes and hides the protected app, which stays locked

**Always test the panic key in a Debug build before working on overlay code.**

## Submitting Changes

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Ensure the project builds without warnings
5. Submit a pull request with a clear description

## Reporting Issues

Use [GitHub Issues](https://github.com/Naosou-3355/Bonsoirnon_maklock/issues) with the provided templates for bug reports and feature requests.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
