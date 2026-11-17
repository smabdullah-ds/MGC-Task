# Bazaar Sort

A hybrid-casual sort puzzle for Android and iOS. Players sort spices, lanterns, teacups and fabrics onto shelves, and spend the coins they earn restoring a historic bazaar.

Flutter 3.50 · Flame · Riverpod 3 · go_router · Hive CE · Firebase · AdMob (+ AppLovin, Unity, Meta, Mintegral mediation) · RevenueCat.

| Doc | What's in it |
| --- | --- |
| `PROGRESS.md` | What was built in each phase, plus a log of the decisions made along the way |
| `RELEASE.md` | Soft-launch checklist (Philippines + Canada), versioning, signing, store setup |
| `KPI.md` | How to read D1/D7 retention, ARPDAU and ad revenue per placement in Firebase |
| `docs/PRIVACY.md` | Play Data safety and App Store privacy answers |

---

## 1. Setup

You need: Flutter **3.50.0** (pinned in `.fvmrc` and CI), Xcode 16+ and CocoaPods for iOS, and Android Studio or the Android SDK (API 36) for Android.

```bash
flutter pub get
flutter gen-l10n
flutter test                 # ~200 tests, including a replay of all 1,000 bundled levels
flutter run                  # works immediately: fake ads/IAP/analytics, Google test ad IDs
```

The app runs with **no keys at all**. Every external SDK sits behind an interface (`AdsService`, `IapService`, `AnalyticsService`, `RemoteConfigService`, `ConsentService`, `NotificationService`, `StorageService`) with a fake implementation. `lib/app/bootstrap.dart` switches each one to the real SDK only when that SDK is configured.

## 2. Adding keys (never commit them)

| Where | Holds | Template |
| --- | --- | --- |
| `.env.json` | Dart-side config: RevenueCat keys, AdMob **ad unit** IDs, feature flags, privacy and support links | `.env.example.json` |
| `android/key.properties` | Upload keystore + Android AdMob **app** ID | `android/key.properties.example` |
| `ios/Flutter/Secrets.xcconfig` | iOS AdMob **app** ID | `ios/Flutter/Secrets.xcconfig.example` |
| `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` | Firebase | created by `flutterfire configure` |

All of these files are git-ignored. Pass the Dart config at build time:

```bash
cp .env.example.json .env.json            # then edit
flutter run --dart-define-from-file=.env.json
flutter build appbundle --dart-define-from-file=.env.json
```

**Firebase.** Run `dart pub global activate flutterfire_cli`, then `flutterfire configure --project=<your-project>`. Set `"FIREBASE_ENABLED": true` in `.env.json`. On Android, the Firebase Gradle plugins only apply when `google-services.json` exists. On iOS, make sure `GoogleService-Info.plist` is part of the Runner target. To upload dSYMs, add the Crashlytics run-script phase in Xcode (see the Firebase docs).

**AdMob.** Put the app IDs in `key.properties` / `Secrets.xcconfig` and the ad unit IDs in `.env.json`. Mediation networks are configured in the AdMob console; the adapters are already linked.

**RevenueCat.** Set `REVENUECAT_ANDROID_KEY` / `REVENUECAT_IOS_KEY` in `.env.json`, then create these products and entitlements in the dashboard:

| Product ID | Type | Entitlement |
| --- | --- | --- |
| `remove_ads` | Non-consumable | `no_ads` |
| `starter_pack` | Non-consumable | `no_ads` |
| `coins_s`, `coins_m`, `coins_l`, `coins_xl` | Consumable | – |
| `booster_bundle` | Consumable | – |
| `vip_weekly` | Auto-renewing subscription (1 week) | `vip` |

## 3. Regenerating levels

```bash
dart run tool/generate_levels.dart                 # levels 1–1000 → assets/levels/*.json (~8 min on 4 cores)
dart run tool/generate_levels.dart --from 1 --to 200 --workers 8
dart run tool/generate_levels.dart --check         # replays every stored solution
```

Levels are deterministic: the same `(level, seed)` always gives the same board, because the generator uses a pinned PRNG and node limits rather than time limits. Each file stores the board, seed, optimal move count, tags and the solver's solution. The tests replay every solution, so a bundled level can never be unsolvable.

To change the difficulty curve, edit `DifficultyCurveConfig` defaults in `lib/core/level_gen/difficulty_curve.dart`, then regenerate. You can also override it live with the `difficulty_curve_json` Remote Config key, which affects levels generated on device after level 1000 and daily challenges.

## 4. Swapping in real art

- **Goods:** implement `ItemSkin` (`lib/features/gameplay/skins/item_skin.dart`), for example with a sprite sheet, and return it from `itemSkinProvider`. Item types are plain ints, so no game logic changes.
- **Bazaar items:** replace the icons in `_itemIcons` (`lib/features/meta/bazaar_screen.dart`) with images.
- **Icon and splash:** replace the PNGs in `assets/branding/`, then run `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`. You can redraw the placeholders with `python3 tool/make_brand_assets.py`.
- **Audio:** replace the files in `assets/audio/`; the file names are the contract (`Sfx` enum). Regenerate the placeholders with `python3 tool/synth_audio.py`.

## 5. Project layout

```
lib/
  app/            bootstrap, startup (consent → ATT → SDKs), router, theme, palette
  config/         env.dart (build-time config), constants, remote_config_defaults.dart
  core/           PURE DART, ~99% test coverage
    game_logic/   board, shelves, items, moves, rules + obstacle modules, session/undo, stars
    level_gen/    solver (A*), generator, difficulty curve, shuffle booster, PRNG
    economy/      progression, bazaar catalog, daily, purchases, interstitial pacing, reminders, save migrations
  features/       gameplay (Flame board, HUD, flows), home, meta (bazaar), daily, shop, settings, splash, screenshots
  services/       ads, iap, analytics, remote_config, storage, notifications, consent, audio (+ fakes)
  l10n/           ARB files (en complete; ur, ar, de, es, fr, id, tr scaffolded)
tool/             generate_levels.dart, check_coverage.dart, synth_audio.py, make_brand_assets.py
```

## 6. Quality gates

CI (`.github/workflows/ci.yml`) runs format, `flutter analyze --fatal-infos`, all tests with coverage, and a check that `lib/core` has at least 80% line coverage.

## 7. Store screenshots

Debug and profile builds include `/debug/screenshots`, a set of staged scenes with marketing captions. Open it with `flutter run --profile --route=/debug/screenshots`, or launch the app and navigate to the route. Release builds only include it with `--dart-define=SCREENSHOTS=true`.

---

## 8. Things you must do manually

These need your accounts and can't be done from code.

**Firebase**
1. Create two Firebase projects, `bazaar-sort-dev` and `bazaar-sort-prod`. Run `flutterfire configure` for each, and keep the config files out of git.
2. Enable Analytics, Crashlytics, Remote Config and Cloud Messaging. Link Analytics to AdMob and to Google Play.
3. Import the Remote Config template: every key and default in `lib/config/remote_config_defaults.dart`.
4. iOS push: upload an APNs auth key (Apple Developer → Keys) to Firebase → Cloud Messaging.

**AdMob and mediation**

5. Create an AdMob account and two apps (Android and iOS). Create ad units: rewarded, interstitial, banner and app-open for each platform.
6. Set up mediation groups for AppLovin MAX, Unity Ads, Meta Audience Network and Mintegral. Each network needs its own account, app and placement IDs. Then fill in the AdMob mediation settings.
7. AdMob → Privacy & messaging: create the **GDPR** message and the **US state regulations** message (UMP), and an IDFA explainer for iOS.
8. Add the app-ads.txt file to your developer website.

**RevenueCat and the stores**

9. Create a RevenueCat project. Add the Play app (service-account JSON) and the App Store app (App Store Connect API key / shared secret).
10. Create the products and entitlements from section 2, in Play Console, App Store Connect and RevenueCat.

**Store listings**

11. Google Play Console: create the app with package `com.bazaarsort.game` (change it in `android/app/build.gradle.kts` first if you want a different ID). Fill in the content rating questionnaire (general audience, 13+), the target audience (13+, **not** designed for children, not enrolled in Families), the Data safety form (`docs/PRIVACY.md`), "Contains ads: yes", and the store listing.
12. App Store Connect: create the app with bundle ID `com.bazaarsort.game`, the age rating, the App Privacy answers (`docs/PRIVACY.md`), the IAP products, and the subscription group for `vip_weekly`.
13. Generate the Android upload keystore and enroll in Play App Signing (`RELEASE.md`). Set up an iOS distribution certificate and provisioning profile, or let Xcode manage signing.

**Legal and support**

14. Publish a privacy policy covering AdMob and its mediation partners, Firebase, RevenueCat, the advertising ID and IDFA, and GDPR/CCPA rights. Put its URL in `.env.json` (`PRIVACY_POLICY_URL`) and in both store listings.
15. Set up a support e-mail address (`SUPPORT_EMAIL`), and terms of service if you want them.
16. Get the `ur`, `ar`, `de`, `es`, `fr`, `id` and `tr` translations completed and reviewed. Then add each language to `shippedLanguages` in `lib/features/settings/locales.dart`.
