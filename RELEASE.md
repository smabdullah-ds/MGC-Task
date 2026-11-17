# Release checklist — soft launch (Philippines + Canada)

**Why these two markets.** The Philippines gives cheap installs, which makes it quick to read retention and spot stability problems. Canada behaves like the US/UK in monetisation, so it gives an early read on ARPDAU and IAP conversion before scaling Tier-1 user acquisition.

## 0. Versioning

- `pubspec.yaml` → `version: <marketing>+<build>`, for example `1.0.0+1`.
- **Marketing version** (semver): bump *minor* for content or features and *patch* for fixes.
- **Build number** must go up with every store upload, on both platforms. CI can use `--build-number=$(git rev-list --count HEAD)`.
- Tag each store build: `git tag v1.0.0+12 && git push --tags`.

## 1. One-time setup

- [ ] All manual steps in README §8 are done (Firebase, AdMob plus mediation, UMP messages, RevenueCat, store listings).
- [ ] **Android upload key**:
  ```bash
  keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  cp android/key.properties.example android/key.properties   # fill in passwords + AdMob app id
  ```
  Enroll in **Play App Signing** and back up the keystore and its passwords somewhere safe (a password manager). Losing them blocks future updates.
- [ ] **iOS signing**: either automatic signing with the team selected in Xcode, or a distribution certificate plus an App Store provisioning profile for `com.bazaarsort.game`.
- [ ] `ios/Flutter/Secrets.xcconfig` contains the real `ADMOB_APP_ID_IOS`.
- [ ] `.env.json` contains production values: `FLAVOR=prod`, `FIREBASE_ENABLED=true`, real ad unit IDs, RevenueCat keys, privacy URL and support e-mail.
- [ ] Remote Config template is published, with the defaults matching `remote_config_defaults.dart`.

## 2. Build

```bash
flutter clean && flutter pub get && flutter gen-l10n
flutter analyze --fatal-infos && flutter test
dart run tool/generate_levels.dart --check

# Android (Play)
flutter build appbundle --release --dart-define-from-file=.env.json \
  --obfuscate --split-debug-info=build/symbols/android
# iOS (App Store Connect)
cd ios && pod install && cd ..
flutter build ipa --release --dart-define-from-file=.env.json \
  --obfuscate --split-debug-info=build/symbols/ios
```

- [ ] Upload the Dart symbols (`build/symbols/*`) to Crashlytics: `firebase crashlytics:symbols:upload`. Upload the iOS dSYMs too.
- [ ] Check download size: the AAB download size shown in Play Console must be under 60 MB, and so must the App Store "estimated download" in TestFlight.

## 3. Pre-launch QA (real devices)

Test on at least: a 2 GB RAM Android 8 phone (target: 60 fps on the board, cold start under 3 s), a mid-range Android 13 phone, an iPhone SE (2nd/3rd gen) and a current iPhone.

- [ ] Fresh install, then the consent flow. Use an EEA VPN or UMP debug geography to see the GDPR form, and a US-state geography for the state-regulation message. After that, the ATT prompt (iOS) appears, and only then do ads load.
- [ ] Decline everything: non-personalised ads still serve, and the game works.
- [ ] Airplane mode from cold start: the game is fully playable, ad buttons say "no video available", the shop shows the offline message, and nothing crashes.
- [ ] Tutorial levels 1–10: the coach text and guide hand appear, and no interstitials show.
- [ ] Interstitials: none before level 10. After that, every 2–3 completed levels, at least 90 s apart, none for 3 minutes after a rewarded ad, none after a level you failed or restarted, never mid-level.
- [ ] Rewarded placements: hint, extra shelf, undo refill, 2× coins, daily spin, extra moves. Each grants exactly once.
- [ ] Kill the app on the win screen, then reopen: progress and coins are kept, and 2× can't be claimed twice.
- [ ] Purchases with sandbox/test accounts: every product, cancel, pending (Play "slow test card"), refund (Play Console) → remove_ads entitlement revoked, restore on a fresh install, VIP renewal and expiry.
- [ ] Remove ads: no interstitials or banners; rewarded ads still offered.
- [ ] Reminders: opt in at level 6, then background the app → reminders are scheduled. Check the quiet hours, and that at most one fires per day.
- [ ] Settings: every toggle works and persists, manage consent re-opens UMP, the privacy link opens, the support e-mail opens.
- [ ] Colourblind mode: every item shows a symbol. Dynamic Type at its largest size: nothing is clipped.
- [ ] Crashlytics: force a test crash in a debug build and confirm it arrives.
- [ ] Analytics: in DebugView, every event in KPI.md §1 arrives with its parameters.

## 4. Store submission

- [ ] Play: internal testing → closed testing → **production with countries limited to the Philippines and Canada**. Data safety form per `docs/PRIVACY.md`, "Contains ads", target audience 13+, not in the Families programme.
- [ ] App Store: TestFlight, then submission with availability limited to PH and CA. App Privacy answers per `docs/PRIVACY.md`. Answer "yes" to the IDFA usage questions (third-party advertising).
- [ ] Screenshots: `/debug/screenshots` (README §7), plus a 15–30 s gameplay video for both stores.

## 5. Soft-launch monitoring (first 2–4 weeks)

| Metric | Gate to scale |
| --- | --- |
| Crash-free users | ≥ 99.5% |
| D1 retention | ≥ 35% |
| D7 retention | ≥ 14% |
| ARPDAU (ads + IAP, blended) | ≥ $0.08 (CA); track PH separately |
| Level 10 / 20 / 40 completion funnel | no single level losing > 8% of players |
| Ad fill (rewarded, CA) | ≥ 95% |

Use Remote Config experiments to tune before scaling: interstitial gap (2 vs 3), starter-pack timer, booster prices, coin rewards, and the `difficulty_curve_json` ramp. Change one thing per experiment, and run each for at least 7 days.

## 6. Go / no-go for Tier-1 scale

- [ ] Every gate in §5 is met for 2 consecutive weeks.
- [ ] No open P0/P1 crash clusters.
- [ ] Translations for the target markets are reviewed (`shippedLanguages` updated).
- [ ] UA creatives tested (CPI read in CA).
