# Bazaar Sort

Hybrid-casual sort puzzle (Flutter + Flame) set in a historic bazaar.
See `PROGRESS.md` for build status. Full setup notes are added as phases land.

## Quick start

```bash
flutter pub get
flutter gen-l10n
flutter test
flutter run            # uses fake ads/IAP/analytics until keys are configured
```

## Build an Android APK

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
