# Utility Apps

Flutter + Melos monorepo for independent Android utility apps with shared packages.

## Repository layout
- `apps/` — independently publishable Flutter applications
- `packages/` — reusable Flutter/Dart packages
- `docs/` — architecture and publishing guidance
- `.devcontainer/` — optional cloud development environment
- `.github/workflows/` — optional manually-triggered CI builds

## Local Android development

The repository is designed to support local Flutter development. Install Flutter, Java and Android SDK on your development machine/device, then run:

```bash
melos bootstrap
bash tool/build_image_compressor.sh
```

The build script resolves dependencies, runs static analysis and creates both APK and AAB. It runs Flutter tests only when the app has a test directory.

Outputs:
- `apps/image_compressor/build/app/outputs/flutter-apk/app-release.apk`
- `apps/image_compressor/build/app/outputs/bundle/release/app-release.aab`

## Optional GitHub Actions

The Android build workflow is manual-only. It does not run on pushes, so normal code commits do not consume GitHub Actions minutes. To opt in, open **Actions → Build Image Compressor (manual only) → Run workflow**.

## Image Compressor features

- Pick a photo from the device gallery
- Adjust JPEG compression quality
- Preview the compressed result
- Compare original and compressed file sizes
- Save the result to the device gallery
- Share the compressed image
- On-device processing; photos are not uploaded
- Google Mobile Ads banner integration using Google's official test ad unit

## Add another app

Create a new Flutter app under `apps/<app_slug>`, add local path dependencies for shared packages, include it in Melos, and add its own build configuration when ready.

## Release notes

- Each app needs a unique Android application ID, app name, icons, assets, and release signing configuration.
- AdMob currently uses Google's sample app ID and test banner ID. Replace them with your own production IDs before release.
- Production Play Billing, purchase verification, and restore-purchase flows are not implemented yet.
- The release APK/AAB produced by the local script are not Play Store upload-signed. Configure a private upload keystore and Gradle signing before publishing. Never commit keystore files or passwords.
