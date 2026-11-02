#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/image_compressor"

cd "$ROOT_DIR"
export PATH="$HOME/.pub-cache/bin:$PATH"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found. Install Flutter and add it to PATH first." >&2
  exit 1
fi

if ! command -v melos >/dev/null 2>&1; then
  dart pub global activate melos 6.3.2
fi

melos bootstrap

cd "$APP_DIR"
if [ ! -d android ]; then
  flutter create --platforms=android --org com.utilityapps .
fi

python3 - <<'PY'
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()
app_id_key = "com.google.android.gms.ads.APPLICATION_ID"
test_app_id = "ca-app-pub-3940256099942544~3347511713"
if app_id_key not in text:
    meta = f'''\n        <!-- Google sample AdMob app ID. Replace before production release. -->
        <meta-data
            android:name="{app_id_key}"
            android:value="{test_app_id}" />
'''
    text = text.replace("</application>", meta + "    </application>")
    manifest.write_text(text)
PY

flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release

echo
echo "Build complete:"
echo "APK: $APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
echo "AAB: $APP_DIR/build/app/outputs/bundle/release/app-release.aab"
