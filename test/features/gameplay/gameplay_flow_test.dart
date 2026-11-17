import 'package:bazaar_sort/core/economy/player_state.dart';
import 'package:bazaar_sort/core/game_logic/game_logic.dart';
import 'package:bazaar_sort/features/gameplay/board/board_game.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/services/audio/feedback_service.dart';
import 'package:bazaar_sort/services/storage/memory_storage_service.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

BoardGame _game(WidgetTester tester) => tester
    .widget<GameWidget<BoardGame>>(find.byType(GameWidget<BoardGame>))
    .game!;

void main() {
  // Level 12 so no tutorial coach covers the board.
  final winnable = testLevel(const [
    [0, 0, 0, 1],
    [1, 1, 1, 0],
    [],
  ]);

  group('win flow', () {
    testWidgets('win saves progress before the panel, then continues', (
      tester,
    ) async {
      final deps = TestDeps();
      final container = await pumpApp(
        tester,
        deps,
        location: '/play/12',
        levels: {
          12: winnable,
          13: testLevel(const [
            [0, 0, 0, 1],
            [1, 1, 1, 0],
            [],
          ], level: 13),
        },
      );
      expect(find.byKey(const ValueKey('level_title')), findsOneWidget);
      final c = _game(tester).controller
        ..play(const Move(0, 2))
        ..play(const Move(1, 0))
        ..play(const Move(1, 2));
      expect(c.status, SessionStatus.won);
      await settle(tester, 20);

      // Saved before the panel appears: killing the app now loses nothing.
      final saved = SaveMigrationsHelper.read(deps.storage);
      expect(saved.nextLevel, 13);
      expect(saved.stars[12], 3);
      expect(saved.coins, 50);

      expect(find.byKey(const ValueKey('win_panel')), findsOneWidget);
      expect(find.text('+50'), findsOneWidget);
      expect(deps.analytics.named('level_complete'), hasLength(1));
      expect(deps.feedback.played, contains(Sfx.win));

      // 2× coins via rewarded ad.
      await tester.tap(find.byKey(const ValueKey('win_double')));
      await settle(tester);
      expect(container.read(playerProvider).coins, 100);
      expect(deps.ads.rewardedShown, hasLength(1));
      expect(find.text('+100'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('win_continue')));
      await settle(tester);
      expect(find.text('Level 13'), findsOneWidget);
      // Interstitials start at level 10 but need a 2–3 level gap first.
      expect(deps.ads.interstitialsShown, isEmpty);
    });

    testWidgets('win panel hides 2× when no rewarded ad is available', (
      tester,
    ) async {
      final deps = TestDeps()..ads.fill = false;
      await pumpApp(tester, deps, location: '/play/12', levels: {12: winnable});
      _game(tester).controller
        ..play(const Move(0, 2))
        ..play(const Move(1, 0))
        ..play(const Move(1, 2));
      await settle(tester, 20);
      expect(find.byKey(const ValueKey('win_panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('win_double')), findsNothing);
    });
  });

  group('fail flow', () {
    // Unsolvable (types 1 and 2 have one copy); after 0→2 nothing can move.
    final stuckAfterOne = testLevel(const [
      [0, 1],
      [0, 2],
      [],
    ], capacity: 2);

    testWidgets('stuck shows options; extra shelf for coins continues', (
      tester,
    ) async {
      // Full shelves, no room: stuck, but solvable with one more shelf.
      final noRoom = testLevel(const [
        [0, 1],
        [1, 0],
      ], capacity: 2);
      final deps = TestDeps(player: const PlayerState(coins: 500));
      final container = await pumpApp(
        tester,
        deps,
        location: '/play/12',
        levels: {12: noRoom},
      );
      final c = _game(tester).controller;
      expect(c.status, SessionStatus.stuck);
      await settle(tester);
      expect(find.byKey(const ValueKey('fail_panel')), findsOneWidget);
      expect(
        deps.analytics.named('level_fail').single.parameters['reason'],
        'stuck',
      );

      await tester.tap(find.byKey(const ValueKey('fail_extra_shelf')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('offer_coins')));
      await settle(tester);

      expect(find.byKey(const ValueKey('fail_panel')), findsNothing);
      expect(c.board.shelfCount, 3);
      expect(c.status, SessionStatus.playing);
      expect(container.read(playerProvider).coins, 380);
      expect(
        deps.analytics.named('booster_used').single.parameters,
        containsPair('source', 'coins'),
      );
    });

    testWidgets('retry restarts the level; home leaves', (tester) async {
      final deps = TestDeps();
      await pumpApp(
        tester,
        deps,
        location: '/play/12',
        levels: {12: stuckAfterOne},
      );
      final c = _game(tester).controller..play(const Move(0, 2));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('fail_retry')));
      await settle(tester);
      expect(c.session.movesMade, 0);
      expect(deps.analytics.named('level_restart'), hasLength(1));
      expect(c.restarts, 1);
      // This test board is unsolvable, so dead-end detection reports it
      // again right after the restart.
      expect(c.isDeadEnd, isTrue);
      await tester.tap(find.byKey(const ValueKey('fail_home')));
      await settle(tester);
      expect(find.byKey(const ValueKey('home_play')), findsOneWidget);
    });

    testWidgets('out of moves offers extra moves via ad', (tester) async {
      final deps = TestDeps();
      final limited = testLevel(const [
        [0, 0, 0, 1],
        [1, 1, 1, 0],
        [],
      ], moveLimit: 1);
      await pumpApp(tester, deps, location: '/play/12', levels: {12: limited});
      expect(find.text('1 move left'), findsOneWidget);
      final c = _game(tester).controller..play(const Move(0, 2));
      await settle(tester);
      expect(find.byKey(const ValueKey('fail_panel')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fail_moves')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('offer_ad')));
      await settle(tester);
      expect(c.status, SessionStatus.playing);
      expect(c.session.movesLeft, 5);
      expect(deps.ads.rewardedShown, hasLength(1));
    });
  });

  testWidgets('pause → restart and undo booster', (tester) async {
    final deps = TestDeps();
    await pumpApp(tester, deps, location: '/play/12', levels: {12: winnable});
    final c = _game(tester).controller..play(const Move(0, 2));
    await settle(tester, 4);
    await tester.tap(find.byKey(const ValueKey('booster_undo')));
    await settle(tester, 4);
    expect(c.session.movesMade, 0);
    expect(c.session.undosLeft, 2);

    await tester.tap(find.byKey(const ValueKey('pause_button')));
    await settle(tester, 4);
    expect(find.byKey(const ValueKey('pause_panel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pause_restart')));
    await settle(tester, 4);
    expect(find.byKey(const ValueKey('pause_panel')), findsNothing);
  });

  testWidgets('tutorial level shows coach text and records it', (tester) async {
    final deps = TestDeps();
    final level1 = testLevel(const [
      [0, 0, 0, 1],
      [1, 1, 1, 0],
      [],
    ], level: 1);
    final container = await pumpApp(
      tester,
      deps,
      location: '/play/1',
      levels: {1: level1},
    );
    expect(find.textContaining('Tap a shelf'), findsOneWidget);
    expect(deps.analytics.named('tutorial_step'), hasLength(1));
    await tester.tap(find.byTooltip('Got it'));
    await settle(tester, 4);
    expect(container.read(playerProvider).tutorialStepsSeen, contains('pick'));
  });
}

/// Reads the persisted save directly (not through the notifier).
abstract final class SaveMigrationsHelper {
  static PlayerState read(MemoryStorageService s) =>
      PlayerState.fromJson(s.read(saveKey)!);
}
