# Bazaar Sort — Progress

| Phase | Status | Commit summary |
| --- | --- | --- |
| 1. Project setup | ✅ Done | Flutter 3.50 project, strict lints, Riverpod, go_router, env config, 7 service interfaces with fakes, CI |
| 2. Core logic | ✅ Done | Immutable board model, move rules, 3 obstacle rule modules (hidden, locked, frozen), win/stuck, session with undo, move limits, boosters; 99% coverage |
| 3. Solver + generator + 1,000 levels | ✅ Done | A* solver (admissible runs heuristic, canonical hashing, node/time limits, weighted fallback), seeded generator + saw-tooth difficulty curve (Remote Config overridable), shuffle booster, `tool/generate_levels.dart`; 1,000 levels bundled, 97% proven optimal, every one replay-verified in tests |
| 4. Playable game | ✅ Done | Flame board (vector `ItemSkin`, arc moves ~250 ms, lift/shake/pop, sparkles, confetti), tap + drag input, HUD + booster bar, win/fail/pause panels, tutorial coach + guide hand, synthesized SFX/music, haptics, Hive save with atomic writes; widget tests for win and fail flows |
| 5. Economy + bazaar + daily | ✅ Done | Coins/boosters economy, 4 bazaar areas (28 items) with area rewards, 7-day login calendar, date-seeded daily challenge + streak, rewarded free spin, shop with idempotent purchase granting, VIP daily bonus, 48 h starter pack |
| 6. Real SDKs | ✅ Done | Firebase (Analytics, Crashlytics, Remote Config), UMP + ATT consent, AdMob with AppLovin/Unity/Meta/Mintegral mediation adapters (test IDs), RevenueCat; each used only when configured, fakes otherwise |
| 7. Analytics, Remote Config, push | ⏳ | |
| 8. Polish | ⏳ | |
| 9. Release prep | ⏳ | |

## Decisions log

- **App ID** `com.bazaarsort.game` (Android `applicationId` + iOS bundle id). Placeholder — change before the first store upload if you want your studio's domain.
- **Save library** `hive_ce` (maintained fork of Hive). Original `hive`/`isar` are unmaintained.
- **Keys** come from `--dart-define-from-file=.env.json` (git-ignored) via `lib/config/env.dart`; defaults are Google test ad IDs and empty SDK keys (→ fakes). No code generation.
- **Min OS** Android API 24, iOS 15.
- **Riverpod 3** without code generation.
- **Dart 3.14 constructor syntax**: the analyzer prefers `new(...)` / `const new(...)` over repeating the class name; `dart fix --apply` keeps code consistent.
- **Level generation**: the spec asked for a reverse scramble. Pure reverse-move walks almost never land on the start shape (every shelf full or empty): measured < 10% of walks for K ≤ 4 and 0% for K ≥ 5, because such states have very few predecessors. The generator therefore deals the solved board's items into the start shape and **proves** solvability with the solver; the solver's move list is stored with each level and replayed in tests, so every bundled level is verified exactly.
- **Determinism**: levels use a fixed PRNG (mulberry32, pinned by a test) and node limits only, so the same `(level, seed)` gives the same board on any device and SDK.
- **Rules**: "adjacent" for frozen items = neighbouring shelf indexes (i-1, i+1). A move into an empty shelf moves the whole top run.

## Phase 1 details

- `lib/services/*` — `AdsService`, `IapService`, `AnalyticsService`, `RemoteConfigService`, `StorageService`, `NotificationService`, `ConsentService`, each with a fake. Providers in `lib/services/service_providers.dart` default to fakes.
- `lib/config/remote_config_defaults.dart` — every tuning key with its default.
- `test/architecture/core_purity_test.dart` — fails if `lib/core` imports Flutter.
- `.github/workflows/ci.yml` — format, analyze (`--fatal-infos`), tests with coverage, `core/` ≥ 80% gate (`tool/check_coverage.dart`).

## Phase 3 details

- `lib/core/level_gen/solver.dart` — A* with h = total runs − item types (admissible and consistent → optimal at weight 1), canonical keys (shelf order ignored unless frozen items exist), symmetry pruning, node + time limits, weighted A* fallback (near-optimal).
- `lib/core/level_gen/difficulty_curve.dart` — tutorial ramp (K 2→4 over levels 1–10), power-curve growth to K = 10, hard every 5th, breather after, boss every 10th, one empty shelf on late hard levels; obstacles from 20 (hidden), 40 (locked), 60 (frozen), 80 (move limit), each introduced alone. Every knob overridable via the `difficulty_curve_json` Remote Config key.
- `tool/generate_levels.dart` — parallel generation into `assets/levels/levels_XXXX_YYYY.json`; `--check` replays all stored solutions.
- Distribution (1,000 levels): kinds {tutorial 10, normal 594, breather 198, hard 99, boss 99}; obstacles {hidden 488, locked 298, frozen 295, move_limit 185}; median optimal moves 17 (1–100) → 31 (300+).

## Phase 4 details

- **Board**: `features/gameplay/board/` — `BoardGame` (Flame) renders `GameController` state; `BoardLayout` (pure geometry, tested) keeps every shelf a ≥ 48 dp target; `ItemComponent` tweens along a quadratic arc; `ShelfComponent` handles tap and drag-and-drop.
- **Art**: `VectorItemSkin` draws 12 bazaar goods (spice jar, lantern, teacup, silk roll, oil bottle, rose pouch, rug, copper pot, mint tea, pomegranate, dates bowl, brass plate), each with its own silhouette *and* a colourblind symbol. Swap via `itemSkinProvider`.
- **Flow**: `LevelFlow` saves the win (progress + coins in one write) *before* the win panel appears, so killing the app on the win screen loses nothing; the 2× coins grant is idempotent (`LastWin.doubled`).
- **Dead ends**: after each move the solver runs in an isolate; a position proven unwinnable shows the stuck panel even if legal moves remain.
- **Audio**: `tool/synth_audio.py` synthesizes original SFX and a Hijaz-scale music loop (≈ 390 KB of MP3).
- **Storage**: `HiveStorageService` keeps the save as one JSON document plus a `.bak` copy of the previous version.

### APK milestone (run on your machine — this container has no Android SDK)

```bash
flutter pub get
flutter build apk --release                     # uses fake/test services, no keys needed
adb install -r build/app/outputs/flutter-apk/app-release.apk
# or: flutter run --release   (with a phone connected over USB, USB debugging on)
```

The release APK is signed with the debug key until Phase 9 adds the upload-key config.

## Phase 5 details

- **Economy** (`core/economy/`): `Progression` (level coins = 20 + 10/star + 50 boss), `BazaarCatalog` (Spice Market 1,300 coins ≈ 25 levels for a non-payer, rising to 150–600 per item), `DailyProgress` (calendar, challenge streak +20 coins/day up to 7, spin wheel), `PurchaseGranter`, `InterstitialPolicy`. All pure Dart, all tested.
- **Purchases**: each transaction id is granted once (`PurchaseState.grantedTransactions`); restores re-apply only entitlements (never coins); refunds remove entitlements; pending purchases are granted when the store update arrives.
- **Screens**: Bazaar (area sections, restore with animation, area-complete dialog, banner slot behind a Remote Config switch), Daily (calendar, challenge, spin wheel), Shop (store-localized prices, owned states, restore purchases, starter-pack countdown).
- **Booster bundle** (`booster_bundle`, $2.99, 3 of each booster) added to satisfy "booster bundles" in the shop spec — not in the original price table, so create it in the stores or remove it from `Products.all`.

## Phase 6 details

- `lib/app/bootstrap.dart` chooses real or fake services: Firebase only with `FIREBASE_ENABLED=true` and successful init; AdMob + UMP/ATT on Android/iOS unless `ADS_ENABLED=false`; RevenueCat only when a key is set. Tests always use fakes.
- `AdMobAdsService`: preloads rewarded/interstitial/app-open, exponential backoff 2 s → 64 s, paid-event revenue (`value_micros`, currency, mediation network) on the event stream, general-audience request configuration (no child/teen treatment, max rating T).
- `UmpConsentService`: UMP update + form, then ATT on iOS, *then* ads initialise. "Manage consent" re-opens the UMP privacy options form.
- `RevenueCatIapService`: entitlements `no_ads` (remove_ads, starter_pack) and `vip` (vip_weekly); pending → purchased and refunds arrive through the customer-info listener; cancelled / pending / already-owned map to the shared `PurchaseStatus`.
- Android: Firebase Gradle plugins applied only if `android/app/google-services.json` exists; Mintegral Maven repo; core-library desugaring; AdMob app id from `ADMOB_APP_ID_ANDROID` (key.properties or env), test id by default.
- iOS: `GADApplicationIdentifier` from `ADMOB_APP_ID_IOS` (git-ignored `ios/Flutter/Secrets.xcconfig`), ATT usage string, SKAdNetwork ids for Google + the four mediation networks.
- **Not verified on a device**: this container has no Android SDK (dl.google.com is blocked here) and no Xcode, so native builds must be run on your machine.
