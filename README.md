<p align="center">
  <img src="Resources/icon.png" width="128" height="128" alt="Bonsoir, non">
</p>

<h1 align="center">Bonsoir, non</h1>

<p align="center">
  <strong>Verrouille n'importe quelle app macOS avec Touch ID, Apple Watch ou un mot de passe.</strong><br>
  Fork de <a href="https://github.com/dutkiewiczmaciej/MakLock">MakLock</a> par Maciej Dutkiewicz (licence MIT).
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-black?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9%2B-FFD213?style=flat-square" alt="Swift">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-white?style=flat-square" alt="License"></a>
</p>

---

App de barre des menus : quand quelqu'un ouvre ou bascule vers une app protégée, un écran flouté bloque l'accès jusqu'à authentification (Touch ID, Apple Watch au poignet, ou mot de passe de secours).

## Différences avec MakLock

| | MakLock | Bonsoir, non |
|---|---|---|
| Raccourci de secours (`Cmd+Opt+Shift+Ctrl+U`) | Actif partout | Builds Debug uniquement |
| Écran de verrouillage après 60 s | Se ferme et déverrouille | Se ferme, masque l'app, reste verrouillé |
| État de l'Apple Watch inconnu | Considérée au poignet | Considérée verrouillée |
| Mot de passe de secours | Stocké en clair dans le trousseau | Empreinte PBKDF2-SHA256 (600 000 itérations), comparaison à temps constant |
| Essais de mot de passe | Illimités | Blocage progressif après 5 échecs (30 s → 15 min) |
| Mises à jour automatiques | Sparkle (serveur de l'auteur) | Désactivées |
| CI | Non bloquante | Permissions minimales, actions figées par SHA, CodeQL, Dependabot |

## Compiler sur Mac

1. Installer **Xcode 15+** depuis l'App Store.
2. Dans Terminal :
   ```bash
   git clone https://github.com/Naosou-3355/Bonsoirnon_maklock.git
   cd Bonsoirnon_maklock
   open BonsoirNon.xcodeproj
   ```
3. Dans Xcode : **Signing & Capabilities** → choisir ton équipe, puis `Cmd+R`.

## Sécurité

- Liste noire système : Terminal, Finder, Moniteur d'activité, Réglages, Xcode et autres outils ne peuvent jamais être verrouillés.
- En build Debug : bouton « Skip », fermeture automatique après 25 s et raccourci de secours.
- Signalement de vulnérabilités : voir [SECURITY.md](SECURITY.md).

## Configuration requise

- macOS 13 (Ventura) ou plus récent, Apple Silicon ou Intel
- Touch ID recommandé (mot de passe de secours possible)
- Apple Watch sous watchOS 9+ pour le déverrouillage de proximité (optionnel)

## Licence

[MIT](LICENSE) — basé sur MakLock, Copyright (c) 2026 Maciej Dutkiewicz.
