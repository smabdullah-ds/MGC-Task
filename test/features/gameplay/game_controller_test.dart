import 'dart:ui';

import 'package:bazaar_sort/core/game_logic/game_logic.dart';
import 'package:bazaar_sort/core/level_gen/solver.dart';
import 'package:bazaar_sort/features/gameplay/board/board_layout.dart';
import 'package:bazaar_sort/features/gameplay/controller/board_event.dart';
import 'package:bazaar_sort/features/gameplay/controller/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  GameController make(
    List<List<int>> shelves, {
    int capacity = 4,
    int? limit,
  }) => GameController(
    level: testLevel(shelves, capacity: capacity, moveLimit: limit),
    solve: inlineSolve,
  );

  test('tap-select-tap moves and emits events', () async {
    final c = make([
      [0, 0, 0, 1],
      [1, 1, 1, 0],
      [],
    ]);
    final events = <BoardEvent>[];
    c.events.listen(events.add);
    c
      ..tapShelf(0)
      ..tapShelf(2);
    await Future<void>.delayed(Duration.zero);
    expect(events[0], isA<ShelfSelected>());
    expect(events[1], isA<ItemsMoved>());
    expect(c.selected, isNull);
    expect(c.session.movesMade, 1);
  });

  test(
    'tapping the selected shelf deselects; empty shelf is rejected',
    () async {
      final c = make([
        [0, 1],
        [],
      ]);
      final events = <BoardEvent>[];
      c.events.listen(events.add);
      c
        ..tapShelf(1)
        ..tapShelf(0)
        ..tapShelf(0);
      await Future<void>.delayed(Duration.zero);
      expect(events[0], isA<MoveRejected>());
      expect(events[1], isA<ShelfSelected>());
      expect(events[2], isA<SelectionCleared>());
    },
  );

  test('invalid destination shakes; another pickable shelf switches', () async {
    final c = make([
      [0, 0, 0, 1],
      [1, 1, 1, 0],
      [0, 0, 0, 1],
      [],
    ]);
    final events = <BoardEvent>[];
    c.events.listen(events.add);
    c
      ..tapShelf(0)
      ..tapShelf(1);
    await Future<void>.delayed(Duration.zero);
    expect(c.selected, 1);
    expect(events.whereType<MoveRejected>(), isNotEmpty);
    expect(c.play(const Move(0, 1)), isFalse);
  });

  test('win, undo, extra shelf, moves, restart', () async {
    final c = make([
      [0, 0, 0, 1],
      [1, 1, 1, 0],
      [],
    ]);
    final events = <BoardEvent>[];
    c.events.listen(events.add);
    expect(c.addExtraShelf(), isTrue);
    expect(c.addExtraShelf(), isFalse);
    expect(c.board.shelfCount, 4);
    c.play(const Move(0, 2));
    expect(c.undo(), isTrue);
    expect(c.session.movesMade, 0);
    c
      ..grantUndos(2)
      ..play(const Move(0, 2))
      ..play(const Move(1, 0))
      ..play(const Move(1, 2));
    await Future<void>.delayed(Duration.zero);
    expect(c.status, SessionStatus.won);
    expect(events.whereType<LevelWon>(), hasLength(1));
    expect(c.boostersUsed['undo'], 1);
    expect(c.boostersUsed['extra_shelf'], 1);
    c.restart();
    expect(c.restarts, 1);
    expect(c.session.movesMade, 0);
    expect(c.boostersUsed, isEmpty);
    expect(c.elapsedSeconds, 0);
  });

  test('hint returns the first solver move', () async {
    final c = make([
      [0, 0, 0, 1],
      [1, 1, 1, 0],
      [],
    ]);
    final events = <BoardEvent>[];
    c.events.listen(events.add);
    final move = await c.requestHint();
    expect(move, isNotNull);
    expect(c.hint, move);
    expect(c.rules.isLegal(c.board, move!), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<HintShown>(), hasLength(1));
  });

  test('dead ends are detected even when moves remain', () async {
    final c = GameController(
      // Types 0 and 2 have one copy each, so no sequence can win, yet
      // legal moves remain after the first one.
      level: testLevel(const [
        [0, 1],
        [1, 2],
        [],
      ], capacity: 2),
      solve: (b) async =>
          const Solver().solve(b, limits: const SolverLimits(maxNodes: 5000)),
    )..play(const Move(1, 2));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.isDeadEnd, isTrue);
    expect(c.status, SessionStatus.stuck);
  });

  test('move limit and extra moves', () {
    final c = make(const [
      [0, 0, 0, 1],
      [1, 1, 1, 0],
      [],
    ], limit: 1)..play(const Move(0, 2));
    expect(c.status, SessionStatus.outOfMoves);
    c.addMoves(5);
    expect(c.status, SessionStatus.playing);
  });

  test('shuffle replaces the board', () {
    final c =
        make(const [
          [0, 1],
          [1, 0],
          [],
        ], capacity: 2)..applyShuffle(
          BoardState.fromTypes(const [
            [1, 0],
            [0, 1],
            [],
          ], capacity: 2),
        );
    expect(c.board.shelves[0].items.first.type, 1);
    expect(c.boostersUsed['shuffle'], 1);
    c.dispose();
  });

  group('BoardLayout', () {
    test('every shelf fits on screen with ≥ 48 dp hit areas', () {
      for (final n in [3, 5, 6, 9, 12, 13, 14]) {
        final l = BoardLayout.compute(
          area: const Size(390, 600),
          shelfCount: n,
          capacity: 4,
        );
        expect(l.shelfRects, hasLength(n));
        for (var i = 0; i < n; i++) {
          final r = l.shelfRects[i];
          expect(r.left, greaterThanOrEqualTo(0), reason: 'n=$n');
          expect(r.right, lessThanOrEqualTo(390), reason: 'n=$n');
          expect(r.top, greaterThanOrEqualTo(0), reason: 'n=$n');
          expect(r.bottom, lessThanOrEqualTo(600), reason: 'n=$n');
          expect(l.hitRect(i).width, greaterThanOrEqualTo(48));
          expect(l.shelfAt(r.center), i);
        }
        expect(l.itemRect(0, 0).bottom, lessThan(l.shelfRects[0].bottom));
        expect(l.liftHeight, greaterThan(0));
      }
      final l = BoardLayout.compute(
        area: const Size(390, 600),
        shelfCount: 3,
        capacity: 4,
      );
      expect(l.shelfAt(const Offset(-50, -50)), isNull);
    });
  });
}
