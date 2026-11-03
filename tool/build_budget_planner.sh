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
import re
text = re.sub(r'android:label="[^"]*"', 'android:label="Budget Planner"', text, count=1)
if 'android:icon=' not in text:
    text = text.replace('<application', '<application android:icon="@mipmap/ic_launcher"', 1)
app_id_key = "com.google.android.gms.ads.APPLICATION_ID"
admob_app_id = "ca-app-pub-6855248878156856~9798987362"
meta_pattern = r'<meta-data(?=[^>]*android:name="' + re.escape(app_id_key) + r'")[^>]*/>'
meta_replacement = f'<meta-data android:name="{app_id_key}" android:value="{admob_app_id}" />'
if re.search(meta_pattern, text):
    text = re.sub(meta_pattern, meta_replacement, text, count=1)
else:
    text = text.replace("</application>", f'    {meta_replacement}\n    </application>')
manifest.write_text(text)

# SVSystem adaptive launcher icon (Android 8+).
res = Path("android/app/src/main/res")
(res / "drawable").mkdir(parents=True, exist_ok=True)
(res / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
(res / "values").mkdir(parents=True, exist_ok=True)
(res / "drawable/ic_launcher_foreground.xml").write_text("""<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="512" android:viewportHeight="512">
    <path android:fillColor="#1D4ED8" android:pathData="M104,104 H408 V408 H104 Z"/>
    <path android:strokeColor="#FFFFFF" android:strokeWidth="24"
        android:strokeLineCap="round" android:fillColor="#00000000"
        android:pathData="M162,181 H350 M162,245 H350 M162,309 H267"/>
    <path android:strokeColor="#FACC15" android:strokeWidth="25"
        android:strokeLineCap="round" android:strokeLineJoin="round"
        android:fillColor="#00000000" android:pathData="M296,326 L329,359 L391,284"/>
    <path android:fillColor="#FACC15" android:pathData="M150,169 a12,12 0 1,0 24,0 a12,12 0 1,0 -24,0"/>
    <path android:fillColor="#FACC15" android:pathData="M150,233 a12,12 0 1,0 24,0 a12,12 0 1,0 -24,0"/>
    <path android:fillColor="#FACC15" android:pathData="M150,297 a12,12 0 1,0 24,0 a12,12 0 1,0 -24,0"/>
</vector>
""")
(res / "mipmap-anydpi-v26/ic_launcher.xml").write_text("""<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
""")
(res / "values/ic_launcher_background.xml").write_text("""<resources>
    <color name="ic_launcher_background">#102A56</color>
</resources>
""")
(res / "drawable/launch_background.xml").write_text("""<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/ic_launcher_background"/>
    <item android:gravity="center" android:drawable="@drawable/ic_launcher_foreground"/>
</layer-list>
""")
PY

flutter pub get
flutter analyze
if [ -d test ]; then flutter test; fi
flutter build apk --release
flutter build appbundle --release

echo "APK: $APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
echo "AAB: $APP_DIR/build/app/outputs/bundle/release/app-release.aab"
