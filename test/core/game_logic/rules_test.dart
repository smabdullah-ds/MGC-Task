import 'package:bazaar_sort/core/game_logic/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rules = GameRules.standard;

  group('base move rules', () {
    test('moves the whole matching run onto an empty shelf', () {
      final b = BoardState.fromTypes(const [
        [0, 1, 1],
        [],
      ]);
      final out = rules.apply(b, const Move(0, 1));
      expect(out.count, 2);
      expect(out.itemType, 1);
      expect(out.after.shelves[0].items.map((i) => i.type), [0]);
      expect(out.after.shelves[1].items.map((i) => i.type), [1, 1]);
    });

    test('moves only as many as fit', () {
      final b = BoardState.fromTypes(const [
        [1, 1, 1],
        [0, 0, 1],
      ]);
      final out = rules.apply(b, const Move(0, 1));
      expect(out.count, 1);
      expect(out.after.shelves[0].length, 2);
      expect(out.after.shelves[1].length, 4);
    });

    test('rejections', () {
      final b = BoardState.fromTypes(const [
        [0, 1],
        [1, 1, 1, 1],
        [0, 0, 0, 1],
        [0],
        [],
      ]);
      expect(rules.validate(b, const Move(0, 0)), MoveRejection.sameShelf);
      expect(rules.validate(b, const Move(0, 9)), MoveRejection.outOfRange);
      expect(rules.validate(b, const Move(4, 0)), MoveRejection.sourceEmpty);
      expect(rules.validate(b, const Move(1, 4)), MoveRejection.sourceComplete);
      expect(
        rules.validate(b, const Move(0, 2)),
        MoveRejection.destinationFull,
      );
      expect(rules.validate(b, const Move(0, 3)), MoveRejection.typeMismatch);
      expect(rules.isLegal(b, const Move(0, 4)), isTrue);
      expect(() => rules.apply(b, const Move(0, 3)), throwsArgumentError);
    });

    test('legalMoves lists every legal pair', () {
      final b = BoardState.fromTypes(const [
        [0, 1],
        [1],
        [],
      ]);
      expect(rules.legalMoves(b), const [
        Move(0, 1),
        Move(0, 2),
        Move(1, 0),
        Move(1, 2),
      ]);
    });

    test('completing a shelf is reported and locks it', () {
      final b = BoardState.fromTypes(const [
        [0, 0, 0],
        [1, 0],
      ]);
      final out = rules.apply(b, const Move(1, 0));
      expect(out.completedShelf, 0);
      expect(rules.canPick(out.after, 0), isFalse);
    });

    test('win and stuck detection', () {
      final won = BoardState.fromTypes(const [
        [0, 0, 0, 0],
        [],
      ]);
      expect(rules.isWon(won), isTrue);
      expect(rules.isStuck(won), isFalse);

      final stuck = BoardState.fromTypes(const [
        [0, 1, 0, 1],
        [1, 0, 1, 0],
      ]);
      expect(rules.isWon(stuck), isFalse);
      expect(rules.isStuck(stuck), isTrue);
      expect(rules.legalMoves(stuck), isEmpty);

      final playable = BoardState.fromTypes(const [
        [0, 1],
        [1, 0],
        [],
      ]);
      expect(rules.isStuck(playable), isFalse);
    });

    test('canPick rejects out-of-range', () {
      final b = BoardState.fromTypes(const [
        [0],
      ]);
      expect(rules.canPick(b, -1), isFalse);
      expect(rules.canPick(b, 1), isFalse);
      expect(rules.canPick(b, 0), isTrue);
    });
  });

  group('hidden items', () {
    test('hidden items stop the run and reveal when on top', () {
      final b = BoardState(
        capacity: 4,
        shelves: [
          Shelf([Item.of(2), Item.of(1, hidden: true), Item.of(1)]),
          Shelf.empty(),
        ],
      );
      expect(rules.movableRun(b, 0), 1);
      final out = rules.apply(b, const Move(0, 1));
      expect(out.count, 1);
      expect(out.revealedShelves, [0]);
      expect(out.after.shelves[0].top!.isHidden, isFalse);
    });
  });

  group('locked shelves', () {
    test('locked shelf rejects pick and drop until completions', () {
      final b = BoardState(
        capacity: 2,
        shelves: [
          Shelf([Item.of(0)]),
          Shelf([Item.of(0)]),
          Shelf([Item.of(1)], unlockAfter: 1),
          Shelf([Item.of(1)]),
          Shelf.empty(),
        ],
      );
      expect(rules.validate(b, const Move(2, 4)), MoveRejection.sourceLocked);
      expect(
        rules.validate(b, const Move(3, 2)),
        MoveRejection.destinationLocked,
      );
      final out = rules.apply(b, const Move(0, 1));
      expect(out.completedShelf, 1);
      expect(out.unlockedShelves, [2]);
      expect(rules.isLegal(out.after, const Move(3, 2)), isTrue);
    });
  });

  group('frozen items', () {
    test('frozen top cannot be picked; neighbour completion thaws', () {
      final b = BoardState(
        capacity: 2,
        shelves: [
          Shelf([Item.of(3), Item.of(1, frozen: true)]),
          Shelf([Item.of(0)]),
          Shelf([Item.of(0)]),
          Shelf([Item.of(2, frozen: true)]),
          Shelf([Item.of(2)]),
        ],
      );
      expect(rules.validate(b, const Move(0, 4)), MoveRejection.sourceFrozen);
      final out = rules.apply(b, const Move(2, 1));
      expect(out.completedShelf, 1);
      expect(out.thawedShelves, [0]);
      expect(out.after.shelves[0].hasFrozen, isFalse);
      expect(out.after.shelves[3].hasFrozen, isTrue, reason: 'not adjacent');
    });

    test('frozen item below top stops the run', () {
      final b = BoardState(
        capacity: 4,
        shelves: [
          Shelf([Item.of(1, frozen: true), Item.of(1)]),
          Shelf.empty(),
        ],
      );
      expect(rules.movableRun(b, 0), 1);
    });

    test('custom module list disables obstacles', () {
      const plain = GameRules(modules: []);
      final b = BoardState(
        capacity: 4,
        shelves: [
          Shelf([Item.of(1, frozen: true), Item.of(1)]),
          Shelf.empty(),
        ],
      );
      expect(plain.movableRun(b, 0), 2);
    });
  });

  test('module ids are stable', () {
    expect(GameRules.allModules.map((m) => m.id), [
      'locked',
      'frozen',
      'hidden',
    ]);
  });
}
