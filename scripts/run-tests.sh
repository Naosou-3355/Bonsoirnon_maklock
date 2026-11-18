#!/bin/bash
# Compiles the testable sources together with Tests/*.swift and runs them.
# Uses a separate Keychain service name, so it never touches the app's real data.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(mktemp -d)/bonsoirnon-tests"
swiftc -O \
  BonsoirNon/Core/Policy/LockPolicy.swift \
  BonsoirNon/Core/Storage/KeychainManager.swift \
  BonsoirNon/Models/AuthMethod.swift \
  Tests/*.swift \
  -o "$OUT"
"$OUT"
