# Bazaar Sort — Progress

| Phase | Status | Commit summary |
| --- | --- | --- |
| 1. Project setup | ✅ Done | Flutter 3.50 project, strict lints, Riverpod, go_router, env config, 7 service interfaces with fakes, CI |
| 2. Core logic | ✅ Done | Immutable board model, move rules, 3 obstacle rule modules (hidden, locked, frozen), win/stuck, session with undo, move limits, boosters; 99% coverage |
| 3. Solver + generator + 1,000 levels | ✅ Done | A* solver (admissible runs heuristic, canonical hashing, node/time limits, weighted fallback), seeded generator + saw-tooth difficulty curve (Remote Config overridable), shuffle booster, `tool/generate_levels.dart`; 1,000 levels bundled, 97% proven optimal, every one replay-verified in tests |
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
