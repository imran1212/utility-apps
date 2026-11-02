# Utility Apps

Flutter + Melos monorepo for independent Android utility apps with shared packages.

## Repository layout
- `apps/` — independently publishable Flutter applications
- `packages/` — reusable Flutter/Dart packages
- `docs/` — architecture and publishing guidance
- `.devcontainer/` — mobile-friendly GitHub Codespaces environment
- `.github/workflows/` — cloud APK builds

## Mobile-only development (recommended)

Use Chrome on your Android phone:

1. Open this repository on GitHub.
2. Tap **Code → Codespaces → Create codespace on main**.
3. Wait for the first container setup to finish. It installs Flutter, Dart, Java, Android SDK, and Melos.
4. Use the browser VS Code editor and integrated terminal to edit and run commands.
5. Run `melos bootstrap` after dependency changes.

The Codespaces container is the build machine. Android emulator / USB device debugging is not available inside Codespaces; build APKs in the cloud, download them to the phone, then install them locally for testing.

## Build Image Compressor APK in Codespaces

From the repository root:

```bash
bash tool/build_image_compressor.sh
```

APK output:

`apps/image_compressor/build/app/outputs/flutter-apk/app-release.apk`

## Build APK through GitHub Actions

1. Open **Actions → Build Image Compressor APK**.
2. Choose **Run workflow**.
3. Wait for the job to finish.
4. Open the completed workflow run and download the `image-compressor-release-apk` artifact.

The workflow also runs automatically when Image Compressor or shared packages change.

## Add another app

Create a new Flutter app under `apps/<app_slug>`, add local path dependencies for shared packages, include it in Melos, and add its own build workflow when ready.

## Important release notes

- Each app needs a unique Android application ID, app name, icons, assets, and release configuration.
- The Image Compressor starter uses Google's test AdMob IDs. Replace these with production IDs before release.
- The current premium package is only an entitlement abstraction. Production Play Billing, purchase verification, and restore-purchase flows are not yet implemented.
- The current APK workflow produces a test/release build artifact; it is not a Play Store deployment. Configure secure upload signing and Play Console release separately.
- Codespaces includes limited monthly free compute/storage on personal accounts; stop the codespace when not working to conserve quota.
