#!/usr/bin/env bash
set -euo pipefail

echo "Accepting Android SDK licenses..."
yes | sdkmanager --licenses >/dev/null || true
yes | flutter doctor --android-licenses >/dev/null || true

echo 'export PATH="$HOME/.pub-cache/bin:$PATH"' >> "$HOME/.bashrc"
export PATH="$HOME/.pub-cache/bin:$PATH"

dart pub global activate melos 6.3.2
melos bootstrap

flutter --version
dart --version
flutter doctor -v || true
