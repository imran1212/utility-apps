#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/budget_planner"

cd "$ROOT_DIR"
export PATH="$HOME/.pub-cache/bin:$PATH"

command -v flutter >/dev/null 2>&1 || {
  echo "Flutter SDK not found. Install Flutter and add it to PATH." >&2
  exit 1
}

if ! command -v melos >/dev/null 2>&1; then
  dart pub global activate melos 6.3.2
fi

melos bootstrap
cd "$APP_DIR"

if [ ! -d android ]; then
  flutter create --platforms=android --org com.svsystem --project-name budget_planner .
fi

python3 - <<'PY'
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()
text = text.replace('android:label="budget_planner"', 'android:label="Budget Planner"')
app_id_key = "com.google.android.gms.ads.APPLICATION_ID"
test_app_id = "ca-app-pub-3940256099942544~3347511713"
if app_id_key not in text:
    meta = f'''
        <!-- Google sample AdMob app ID. Replace before production release. -->
        <meta-data
            android:name="{app_id_key}"
            android:value="{test_app_id}" />
'''
    text = text.replace("</application>", meta + "    </application>")
manifest.write_text(text)
PY

flutter pub get
flutter analyze
if [ -d test ]; then flutter test; fi
flutter build apk --release
flutter build appbundle --release

echo "APK: $APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
echo "AAB: $APP_DIR/build/app/outputs/bundle/release/app-release.aab"
