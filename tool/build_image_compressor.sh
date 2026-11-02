#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/image_compressor"

cd "$ROOT_DIR"
export PATH="$HOME/.pub-cache/bin:$PATH"

dart pub global activate melos 6.3.2
melos bootstrap

cd "$APP_DIR"
if [ ! -d android ]; then
  flutter create --platforms=android --org com.utilityapps .
fi

python3 - <<'PY'
from pathlib import Path
manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()
marker = 'com.google.android.gms.ads.APPLICATION_ID'
if marker not in text:
    meta = '''
        <!-- Google test AdMob app ID. Replace before production release. -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-3940256099942544~3347511713" />
'''
    text = text.replace("</application>", meta + "\n    </application>")
    manifest.write_text(text)
PY

flutter pub get
flutter build apk --release
echo "APK: $APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
