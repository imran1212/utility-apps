# Utility Apps

Flutter + Melos monorepo for independent Android utility apps with shared packages.

## Structure
- `apps/` — independently publishable Flutter applications
- `packages/` — reusable Flutter/Dart packages
- `docs/` — architecture and publishing guidance

## Bootstrap
```bash
dart pub global activate melos
melos bootstrap
cd apps/image_compressor
flutter create --platforms=android .
flutter run
```

Build:
```bash
cd apps/image_compressor
flutter build appbundle --release
```

Each app owns its Android application ID, branding, icons, assets, and release configuration. The starter uses Google's test AdMob IDs. Replace them and implement/verify Play Billing before production. Run `melos run analyze` and device tests before publishing.
