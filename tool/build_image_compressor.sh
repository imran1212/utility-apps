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
if not gradle.exists():
    raise SystemExit("Android app Gradle file was not found.")
text = gradle.read_text()
if gradle.suffix == ".kts":
    dependency = 'implementation("id.zelory:compressor:3.0.1")'
else:
    dependency = "implementation 'id.zelory:compressor:3.0.1'"
if dependency not in text:
    text, count = re.subn(r"dependencies\s*\{", lambda m: m.group(0) + "\n    " + dependency, text, count=1)
    if count != 1:
        raise SystemExit("Could not add Compressor dependency to Gradle.")
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
import android.content.Context
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.graphics.Color
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import com.google.android.gms.ads.nativead.MediaView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory
"""
    first_line_end = source.find("\n")
    if first_line_end < 0:
        raise SystemExit("Unexpected MainActivity.kt format.")
    source = source[:first_line_end + 1] + imports + source[first_line_end + 1:]
    activity = """class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "imageCompressorNative", ImageCompressorNativeAdFactory(this))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "svsystem/image_compressor")
            .setMethodCallHandler { call, result ->
                if (call.method != "compress") {
                    result.notImplemented()
                } else {
                    val sourcePath = call.argument<String>("sourcePath")
                    val quality = (call.argument<Int>("quality") ?: 80).coerceIn(10, 100)
                    val width = (call.argument<Int>("maxWidth") ?: 4096).coerceIn(1, 8192)
                    val height = (call.argument<Int>("maxHeight") ?: 4096).coerceIn(1, 8192)
                    val targetBytes = (call.argument<Number>("targetBytes") ?: 0).toLong()
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

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "imageCompressorNative")
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

class ImageCompressorNativeAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        val d = context.resources.displayMetrics.density
        fun dp(v: Int) = (v * d + 0.5f).toInt()
        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(10), dp(12), dp(12))
            setBackgroundColor(Color.WHITE)
        }
        root.addView(TextView(context).apply { text = "Advertisement"; textSize = 11f; setTextColor(Color.DKGRAY) })
        val header = LinearLayout(context).apply { orientation = LinearLayout.HORIZONTAL; gravity = android.view.Gravity.CENTER_VERTICAL }
        val icon = ImageView(context).apply {
            layoutParams = LinearLayout.LayoutParams(dp(52), dp(52)).apply { marginEnd = dp(10) }
            scaleType = ImageView.ScaleType.CENTER_CROP
            setImageDrawable(nativeAd.icon?.drawable)
        }
        header.addView(icon)
        val texts = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL; layoutParams = LinearLayout.LayoutParams(0, -2, 1f) }
        val headline = TextView(context).apply {
            text = nativeAd.headline ?: ""; textSize = 17f; setTextColor(Color.BLACK)
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        texts.addView(headline)
        val advertiser = TextView(context).apply {
            text = nativeAd.advertiser ?: nativeAd.body ?: ""; textSize = 12f; setTextColor(Color.DKGRAY)
        }
        texts.addView(advertiser)
        header.addView(texts)
        root.addView(header)
        val media = MediaView(context).apply {
            layoutParams = LinearLayout.LayoutParams(-1, dp(205)).apply { topMargin = dp(10); bottomMargin = dp(10) }
        }
        root.addView(media)
        val cta = Button(context).apply {
            text = nativeAd.callToAction ?: "Learn more"; isAllCaps = false
            setTextColor(Color.WHITE); setBackgroundColor(Color.rgb(0, 105, 220))
        }
        root.addView(cta, LinearLayout.LayoutParams(-1, dp(48)))
        return NativeAdView(context).apply {
            addView(root, ViewGroup.LayoutParams(-1, -2))
            iconView = icon; headlineView = headline; advertiserView = advertiser
            mediaView = media; callToActionView = cta; setNativeAd(nativeAd)
        }
    }
}"""

    source, count = re.subn(r"class MainActivity\s*:\s*FlutterActivity\(\)", activity, source, count=1)
    if count != 1:
        raise SystemExit("Could not install Compressor method channel in MainActivity.")
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
flutter analyze --no-fatal-infos
if [ -d test ]; then
  flutter test
fi
flutter build apk --release
flutter build appbundle --release

echo
echo "Build complete:"
echo "APK: $APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
echo "AAB: $APP_DIR/build/app/outputs/bundle/release/app-release.aab"
