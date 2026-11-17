import 'package:bazaar_sort/core/game_logic/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Item', () {
    test('packs type and flags', () {
      final i = Item.of(7, hidden: true, frozen: true);
      expect(i.type, 7);
      expect(i.isHidden, isTrue);
      expect(i.isFrozen, isTrue);
      expect(i.revealed().isHidden, isFalse);
      expect(i.thawed().isFrozen, isFalse);
      expect(i.revealed().type, 7);
      expect(i.sameType(Item.of(7)), isTrue);
      expect(Item.of(3).bits, 3);
    });
  });

  group('Shelf', () {
    test('basic accessors', () {
      final s = Shelf([Item.of(1), Item.of(2)]);
      expect(s.length, 2);
      expect(s.top!.type, 2);
      expect(s.isEmpty, isFalse);
      expect(Shelf.empty().top, isNull);
    });

    test('completion requires full and uniform', () {
      expect(
        Shelf([for (var i = 0; i < 4; i++) Item.of(1)]).isComplete(4),
        isTrue,
      );
      expect(
        Shelf([Item.of(1), Item.of(1), Item.of(1)]).isComplete(4),
        isFalse,
      );
      expect(
        Shelf([Item.of(1), Item.of(1), Item.of(2), Item.of(1)]).isComplete(4),
        isFalse,
      );
      expect(Shelf.empty().isComplete(0), isFalse);
    });

    test('json round-trip keeps flags and locks', () {
      final s = Shelf([Item.of(1, hidden: true), Item.of(2)], unlockAfter: 2);
      final back = Shelf.fromJson(s.toJson());
      expect(back.key, s.key);
      expect(back.unlockAfter, 2);
      expect(Shelf.empty().toJson().containsKey('u'), isFalse);
    });

    test('toString mentions lock', () {
      expect(
        Shelf([Item.of(1)], unlockAfter: 1).toString(),
        contains('lock=1'),
      );
    });
  });

  group('BoardState', () {
    final board = BoardState.fromTypes(const [
      [0, 1],
      [1, 0],
      [],
    ], capacity: 2);

    test('json round-trip', () {
      final back = BoardState.fromJson(board.toJson());
      expect(back, board);
      expect(back.hashCode, board.hashCode);
    });

    test('canonical key ignores shelf order', () {
      final swapped = BoardState.fromTypes(const [
        [],
        [1, 0],
        [0, 1],
      ], capacity: 2);
      expect(swapped.key, isNot(board.key));
      expect(swapped.canonicalKey, board.canonicalKey);
    });

    test('canonical key keeps order when frozen items exist', () {
      final a = BoardState(
        capacity: 2,
        shelves: [
          Shelf([Item.of(0, frozen: true)]),
          Shelf.empty(),
        ],
      );
      final b = BoardState(capacity: 2, shelves: [a.shelves[1], a.shelves[0]]);
      expect(a.canonicalKey, isNot(b.canonicalKey));
    });

    test('feature flags and counts', () {
      expect(board.itemTypes, {0, 1});
      expect(board.shelfCount, 3);
      expect(board.freeSpace(2), 2);
      expect(board.completedCount, 0);
      expect(board.hasFrozen || board.hasHidden || board.hasLocks, isFalse);
      final extra = board.withExtraShelf();
      expect(extra.shelfCount, 4);
      expect(extra.toString(), contains('BoardState'));
    });

    test('locks open after enough completions', () {
      final b = BoardState(
        capacity: 2,
        shelves: [
          Shelf([Item.of(0), Item.of(0)]),
          Shelf.empty().withItems(const []),
          Shelf(const [], unlockAfter: 2),
        ],
      );
      expect(b.completedCount, 1);
      expect(b.isLocked(2), isTrue);
      expect(b.hasLocks, isTrue);
    });

    test('withTopsRevealed reveals only tops', () {
      final b = BoardState(
        capacity: 3,
        shelves: [
          Shelf([Item.of(0, hidden: true), Item.of(1, hidden: true)]),
        ],
      ).withTopsRevealed();
      expect(b.shelves[0].items[0].isHidden, isTrue);
      expect(b.shelves[0].items[1].isHidden, isFalse);
      expect(b.withTopsRevealed(), same(b));
    });
  });

  group('Move', () {
    test('json and equality', () {
      const m = Move(1, 2);
      expect(Move.fromJson(m.toJson()), m);
      expect(m.hashCode, const Move(1, 2).hashCode);
      expect(m.toString(), '1→2');
    });
  });

  group('StarRating', () {
    const r = StarRating();
    test('thresholds are inclusive', () {
      expect(r.stars(moves: 12, optimalMoves: 10), 3);
      expect(r.stars(moves: 13, optimalMoves: 10), 2);
      expect(r.stars(moves: 16, optimalMoves: 10), 2);
      expect(r.stars(moves: 17, optimalMoves: 10), 1);
      expect(r.stars(moves: 5, optimalMoves: 0), 3);
    });
    test('movesFor gives the boundary', () {
      expect(r.movesFor(3, 10), 12);
      expect(r.movesFor(2, 10), 16);
      expect(r.movesFor(1, 10), greaterThan(1000));
    });
  });
}
