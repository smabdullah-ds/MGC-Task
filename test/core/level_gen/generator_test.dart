import 'package:bazaar_sort/core/game_logic/game_logic.dart';
import 'package:bazaar_sort/core/level_gen/board_shuffler.dart';
import 'package:bazaar_sort/core/level_gen/difficulty_curve.dart';
import 'package:bazaar_sort/core/level_gen/generated_level.dart';
import 'package:bazaar_sort/core/level_gen/level_generator.dart';
import 'package:bazaar_sort/core/level_gen/level_validation.dart';
import 'package:bazaar_sort/core/level_gen/seeded_random.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gen = LevelGenerator();

  group('SeededRandom', () {
    test('same seed, same sequence; known first value', () {
      final a = SeededRandom(42);
      final b = SeededRandom(42);
      final seqA = [for (var i = 0; i < 10; i++) a.nextUint32()];
      final seqB = [for (var i = 0; i < 10; i++) b.nextUint32()];
      expect(seqA, seqB);
      // Pinned so an accidental algorithm change is caught: it would change
      // every level for every player.
      expect(SeededRandom(1).nextUint32(), 2693262067);
    });

    test('ranges and helpers', () {
      final r = SeededRandom(7);
      for (var i = 0; i < 1000; i++) {
        final v = r.nextInt(5);
        expect(v, inInclusiveRange(0, 4));
        expect(r.nextDouble(), inInclusiveRange(0, 1));
      }
      expect([1, 2, 3], contains(r.pick([1, 2, 3])));
      final list = [for (var i = 0; i < 20; i++) i];
      r.shuffle(list);
      expect(list.toSet(), {for (var i = 0; i < 20; i++) i});
      expect(r.chance(1), isTrue);
      expect(r.chance(0), isFalse);
      expect(SeededRandom.derive(1, 2), SeededRandom.derive(1, 2));
      expect(SeededRandom.derive(1, 2), isNot(SeededRandom.derive(1, 3)));
    });
  });

  group('LevelGenerator', () {
    test('is deterministic', () {
      for (final level in [1, 7, 23, 45, 88]) {
        final a = gen.generate(level);
        final b = gen.generate(level);
        expect(a.board, b.board, reason: 'level $level');
        expect(a.optimalMoves, b.optimalMoves);
        expect(a.seed, LevelGenerator.seedFor(level));
      }
    });

    test('different seeds give different boards', () {
      final a = gen.generate(30, seed: 1);
      final b = gen.generate(30, seed: 2);
      expect(a.board, isNot(b.board));
    });

    test('generated levels are solvable and match their spec', () {
      for (var level = 1; level <= 30; level++) {
        final l = gen.generate(level);
        expect(replaySolves(l), isTrue, reason: 'level $level');
        expect(l.board.completedCount, 0);
        expect(l.board.itemTypes.length, l.spec.itemTypes);
        expect(
          l.board.shelves.where((s) => s.isEmpty).length,
          greaterThanOrEqualTo(l.spec.emptyShelves - l.spec.lockedShelves),
        );
      }
    });

    test('obstacles appear from their intro levels', () {
      expect(gen.generate(20).board.hasHidden, isTrue);
      expect(gen.generate(40).board.hasLocks, isTrue);
      final frozen = gen.generate(60);
      expect(frozen.board.hasFrozen || !frozen.tags.contains('frozen'), isTrue);
      expect(gen.generate(80).moveLimit, isNotNull);
    });

    test('json round-trip keeps solution and limit', () {
      final l = gen.generate(80);
      final back = GeneratedLevel.fromJson(l.toJson());
      expect(back.board, l.board);
      expect(back.solution, l.solution);
      expect(back.moveLimit, l.moveLimit);
      expect(back.kind, l.kind);
      expect(back.tags, contains('move_limit'));
      expect(back.isBoss, l.isBoss);
    });

    test('scramble yields the start shape', () {
      final s = LevelGenerator.scramble(
        types: 5,
        capacity: 4,
        rng: SeededRandom(3),
      );
      if (s != null) {
        expect(s, hasLength(5));
        expect(s.every((shelf) => shelf.length == 4), isTrue);
      }
    });

    test('replaySolves rejects a wrong solution', () {
      final l = gen.generate(5);
      final broken = GeneratedLevel(
        level: l.level,
        seed: l.seed,
        spec: l.spec,
        board: l.board,
        optimalMoves: l.optimalMoves,
        provenOptimal: false,
        solution: l.solution.reversed.toList(),
      );
      expect(replaySolves(broken), isFalse);
      final short = GeneratedLevel(
        level: l.level,
        seed: l.seed,
        spec: l.spec,
        board: l.board,
        optimalMoves: l.optimalMoves + 1,
        provenOptimal: false,
        solution: l.solution,
      );
      expect(replaySolves(short), isFalse);
    });

    test('relaxes obstacles when a spec cannot be met', () {
      // A curve whose locked shelves can never be satisfied with one empty
      // shelf still yields a solvable level.
      const tough = LevelGenerator(
        curve: DifficultyCurve(
          DifficultyCurveConfig(
            tutorialLevels: 0,
            emptyShelves: 1,
            lockedFromLevel: 1,
            lockedEvery: 1,
            frozenFromLevel: 1,
            frozenEvery: 1,
            startTypes: 3,
            maxTypes: 3,
          ),
        ),
        maxAttempts: 3,
      );
      final l = tough.generate(3);
      expect(replaySolves(l), isTrue);
    });
  });

  group('BoardShuffler', () {
    test('returns a different, solvable board with the same items', () {
      final level = gen.generate(25);
      final shuffled = const BoardShuffler().shuffle(
        level.board,
        SeededRandom(9),
      );
      expect(shuffled, isNotNull);
      expect(shuffled!.key, isNot(level.board.key));
      List<int> types(BoardState b) => [
        for (final s in b.shelves)
          for (final i in s.items) i.type,
      ]..sort();
      expect(types(shuffled), types(level.board));
      for (var i = 0; i < shuffled.shelfCount; i++) {
        expect(shuffled.shelves[i].length, level.board.shelves[i].length);
      }
    });

    test('keeps locked and complete shelves, frozen items in place', () {
      final board = BoardState(
        capacity: 4,
        shelves: [
          Shelf([for (var i = 0; i < 4; i++) Item.of(0)]),
          Shelf([Item.of(1), Item.of(2), Item.of(1), Item.of(2)]),
          Shelf([Item.of(2), Item.of(1), Item.of(2), Item.of(1)]),
          Shelf([Item.of(3), Item.of(3), Item.of(3, frozen: true)]),
          Shelf([Item.of(3)], unlockAfter: 2),
          Shelf.empty(),
        ],
      );
      final out = const BoardShuffler().shuffle(board, SeededRandom(1));
      expect(out, isNotNull);
      expect(out!.shelves[0].key, board.shelves[0].key);
      expect(out.shelves[4].key, board.shelves[4].key);
      expect(out.shelves[3].items[2].isFrozen, isTrue);
    });

    test('nothing to shuffle returns null', () {
      final board = BoardState.fromTypes(const [
        [0],
        [],
      ]);
      expect(const BoardShuffler().shuffle(board, SeededRandom(1)), isNull);
    });
  });
}
