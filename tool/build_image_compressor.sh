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


# Wire the Android Compressor library into the generated app project.
python3 - <<'PY'
from pathlib import Path
import re

gradle = Path("android/app/build.gradle")
if not gradle.exists():
    gradle = Path("android/app/build.gradle.kts")
text = gradle.read_text()
dependency = "implementation 'id.zelory:compressor:3.0.1'"
if gradle.name == "build.gradle":
    if dependency not in text:
        if "dependencies {" not in text:
            raise SystemExit("Could not find dependencies block in Android app Gradle file.")
        text = text.replace("dependencies {", "dependencies {\\n    " + dependency, 1)
else:
    kotlin_dependency = 'implementation("id.zelory:compressor:3.0.1")'
    if kotlin_dependency not in text:
        text = text.replace("dependencies {", "dependencies {\\n    " + kotlin_dependency, 1)
gradle.write_text(text)

main_files = list(Path("android/app/src/main/kotlin").rglob("MainActivity.kt"))
if not main_files:
    raise SystemExit("Generated MainActivity.kt was not found.")
main = main_files[0]
source = main.read_text()
if "svsystem/image_compressor" not in source:
    imports = """import android.graphics.Bitmap
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import id.zelory.compressor.Compressor
import id.zelory.compressor.constraint.default
import id.zelory.compressor.constraint.size
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import java.io.File
"""
    package_end = source.find("\\n")
    source = source[:package_end + 1] + imports + source[package_end + 1:]
    source = source.replace(
        "class MainActivity : FlutterActivity()",
        """class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "svsystem/image_compressor")
            .setMethodCallHandler { call, result ->
                if (call.method != "compress") {
                    result.notImplemented()
                } else {
                    val sourcePath = call.argument<String>("sourcePath")
                    val quality = (call.argument<Int>("quality") ?: 80).coerceIn(10, 100)
                    val width = (call.argument<Int>("maxWidth") ?: 4096).coerceIn(1, 8192)
                    val height = (call.argument<Int>("maxHeight") ?: 4096).coerceIn(1, 8192)
                    val targetBytes = (call.argument<Int>("targetBytes") ?: 0).toLong()
                    if (sourcePath.isNullOrBlank() || !File(sourcePath).isFile) {
                        result.error("INVALID_SOURCE", "Source image does not exist.", null)
                    } else {
                        Thread {
                            try {
                                val compressed = runBlocking(Dispatchers.IO) {
                                    Compressor.compress(applicationContext, File(sourcePath), Dispatchers.IO) {
                                        default(
                                            width = width,
                                            height = height,
                                            format = Bitmap.CompressFormat.JPEG,
                                            quality = quality
                                        )
                                        if (targetBytes > 0L) size(targetBytes)
                                    }
                                }
                                runOnUiThread { result.success(compressed.absolutePath) }
                            } catch (error: Exception) {
                                runOnUiThread {
                                    result.error("COMPRESSION_FAILED", error.message ?: "Compression failed.", null)
                                }
                            }
                        }.start()
                    }
                }
            }
    }
}"""
    )
    main.write_text(source)
PY

python3 - <<'PY'
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()
app_id_key = "com.google.android.gms.ads.APPLICATION_ID"
test_app_id = "ca-app-pub-3940256099942544~3347511713"

if 'android:label="image_compressor"' in text:
    text = text.replace('android:label="image_compressor"', 'android:label="Image Compressor"')

permission = '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />'
if permission not in text:
    text = text.replace("<application", f"    {permission}\n    <application", 1)

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
if [ -d test ]; then
  flutter test
fi
flutter build apk --release
flutter build appbundle --release

echo
echo "Build complete:"
echo "APK: $APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
echo "AAB: $APP_DIR/build/app/outputs/bundle/release/app-release.aab"
