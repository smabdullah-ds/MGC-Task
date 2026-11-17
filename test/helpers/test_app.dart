import 'dart:async';

import 'package:bazaar_sort/app/app.dart';
import 'package:bazaar_sort/app/router.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';
import 'package:bazaar_sort/core/game_logic/game_logic.dart';
import 'package:bazaar_sort/core/level_gen/difficulty_curve.dart';
import 'package:bazaar_sort/core/level_gen/generated_level.dart';
import 'package:bazaar_sort/core/level_gen/solver.dart';
import 'package:bazaar_sort/features/gameplay/data/level_repository.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/services/ads/fake_ads_service.dart';
import 'package:bazaar_sort/services/analytics/fake_analytics_service.dart';
import 'package:bazaar_sort/services/audio/feedback_service.dart';
import 'package:bazaar_sort/services/iap/fake_iap_service.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:bazaar_sort/services/storage/memory_storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Builds a level from item types for widget tests.
GeneratedLevel testLevel(
  List<List<int>> shelves, {
  int level = 12,
  int capacity = 4,
  int optimal = 3,
  int? moveLimit,
  LevelKind kind = LevelKind.normal,
}) => GeneratedLevel(
  level: level,
  seed: 1,
  spec: LevelSpec(
    level: level,
    kind: kind,
    itemTypes: 2,
    capacity: capacity,
    emptyShelves: 1,
    minOptimalMoves: 0,
  ),
  board: BoardState.fromTypes(shelves, capacity: capacity),
  optimalMoves: optimal,
  provenOptimal: true,
  moveLimit: moveLimit,
);

/// Level repository that serves fixed levels.
class FakeLevelRepository extends LevelRepository {
  new(this.levels) : super(bundle: rootBundle, curve: const DifficultyCurve());

  final Map<int, GeneratedLevel> levels;

  @override
  Future<GeneratedLevel> load(int level) async =>
      levels[level] ?? levels.values.first;

  @override
  Future<GeneratedLevel> daily(
    DateTime day, {
    required int playerLevel,
  }) async => levels.values.first;
}

/// Inline solver (no isolates in widget tests).
Future<SolveResult> inlineSolve(BoardState b) async =>
    const Solver().solve(b, limits: SolverLimits.hint);

/// Fakes shared by a test.
class TestDeps {
  new({PlayerState? player, FakeAdsService? ads})
    : ads = ads ?? FakeAdsService(),
      storage = MemoryStorageService() {
    if (player != null) unawaited(storage.write(saveKey, player.toJson()));
  }

  final FakeAdsService ads;
  final MemoryStorageService storage;
  final FakeAnalyticsService analytics = FakeAnalyticsService();
  final FakeFeedbackService feedback = FakeFeedbackService();
  final FakeIapService iap = FakeIapService();

  List<Override> overrides({
    required String location,
    Map<int, GeneratedLevel> levels = const {},
  }) => [
    storageServiceProvider.overrideWithValue(storage),
    adsServiceProvider.overrideWithValue(ads),
    analyticsServiceProvider.overrideWithValue(analytics),
    feedbackServiceProvider.overrideWithValue(feedback),
    iapServiceProvider.overrideWithValue(iap),
    if (levels.isNotEmpty)
      levelRepositoryProvider.overrideWithValue(FakeLevelRepository(levels)),
    solveRunnerProvider.overrideWithValue(inlineSolve),
    routerProvider.overrideWithValue(buildRouter(initialLocation: location)),
  ];
}

/// Pumps the app at [location].
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  TestDeps deps, {
  required String location,
  Map<int, GeneratedLevel> levels = const {},
}) async {
  tester.view
    ..physicalSize = const Size(1080, 2340)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: deps.overrides(location: location, levels: levels),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const BazaarSortApp(),
    ),
  );
  await settle(tester);
  return container;
}

/// Pumps a few frames. Flame's game loop never "settles", so tests advance
/// time explicitly instead of using pumpAndSettle.
Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
