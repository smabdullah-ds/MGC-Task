# Bazaar Sort — Progress

| Phase | Status | Commit summary |
| --- | --- | --- |
| 1. Project setup | ✅ Done | Flutter 3.50 project, strict lints, Riverpod, go_router, env config, 7 service interfaces with fakes, CI |
| 2. Core logic | ✅ Done | Immutable board model, move rules, 3 obstacle rule modules (hidden, locked, frozen), win/stuck, session with undo, move limits, boosters; 99% coverage |
| 3. Solver + generator + 1,000 levels | ⏳ | |
| 4. Playable game | ⏳ | |
| 5. Economy + bazaar + daily | ⏳ | |
| 6. Real SDKs | ⏳ | |
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
- **Rules**: "adjacent" for frozen items = neighbouring shelf indexes (i-1, i+1). A move into an empty shelf moves the whole top run.

## Phase 1 details

- `lib/services/*` — `AdsService`, `IapService`, `AnalyticsService`, `RemoteConfigService`, `StorageService`, `NotificationService`, `ConsentService`, each with a fake. Providers in `lib/services/service_providers.dart` default to fakes.
- `lib/config/remote_config_defaults.dart` — every tuning key with its default.
- `test/architecture/core_purity_test.dart` — fails if `lib/core` imports Flutter.
- `.github/workflows/ci.yml` — format, analyze (`--fatal-infos`), tests with coverage, `core/` ≥ 80% gate (`tool/check_coverage.dart`).
