import 'package:bazaar_sort/core/game_logic/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BoardState simple() => BoardState.fromTypes(const [
    [0, 1],
    [1, 0],
    [],
  ], capacity: 2);

  test('play advances moves and records history', () {
    final s = GameSession.start(simple());
    expect(s.status, SessionStatus.playing);
    expect(s.hasHistory, isFalse);
    final (next, outcome) = s.play(const Move(0, 2))!;
    expect(next.movesMade, 1);
    expect(next.hasHistory, isTrue);
    expect(outcome.count, 1);
  });

  test('illegal move returns null', () {
    final s = GameSession.start(simple());
    expect(s.play(const Move(2, 0)), isNull);
  });

  test('full solve wins and blocks further play', () {
    var s = GameSession.start(simple());
    for (final m in const [Move(0, 2), Move(1, 0), Move(1, 2)]) {
      s = s.play(m)!.$1;
    }
    expect(s.status, SessionStatus.won);
    expect(s.play(const Move(0, 1)), isNull);
  });

  test('undo restores board and moves, consumes a charge', () {
    final s0 = GameSession.start(simple(), freeUndos: 1);
    final s1 = s0.play(const Move(0, 2))!.$1;
    final s2 = s1.undo()!;
    expect(s2.board, s0.board);
    expect(s2.movesMade, 0);
    expect(s2.undosLeft, 0);
    expect(s2.undo(), isNull);
    final s3 = s2.play(const Move(0, 2))!.$1;
    expect(s3.canUndo, isFalse);
    expect(s3.addUndos(3).canUndo, isTrue);
  });

  test('extra shelf once per level', () {
    final s = GameSession.start(simple());
    final s1 = s.addExtraShelf()!;
    expect(s1.board.shelfCount, 4);
    expect(s1.addExtraShelf(), isNull);
  });

  test('move limit ends the session; extra moves resume it', () {
    final s = GameSession.start(simple(), moveLimit: 1);
    expect(s.movesLeft, 1);
    final s1 = s.play(const Move(0, 2))!.$1;
    expect(s1.status, SessionStatus.outOfMoves);
    final s2 = s1.addMoves(5);
    expect(s2.status, SessionStatus.playing);
    expect(s2.movesLeft, 5);
    expect(GameSession.start(simple()).addMoves(5).movesLeft, isNull);
  });

  test('stuck status', () {
    final s = GameSession.start(
      BoardState.fromTypes(const [
        [0, 1],
        [1, 0],
      ], capacity: 2),
    );
    expect(s.status, SessionStatus.stuck);
    expect(s.addExtraShelf()!.status, SessionStatus.playing);
  });

  test('replaceBoard clears history and reveals tops', () {
    final s = GameSession.start(simple()).play(const Move(0, 2))!.$1;
    final hidden = BoardState(
      capacity: 2,
      shelves: [
        Shelf([Item.of(0), Item.of(0, hidden: true)]),
      ],
    );
    final r = s.replaceBoard(hidden);
    expect(r.hasHistory, isFalse);
    expect(r.board.shelves[0].top!.isHidden, isFalse);
  });

  test('history is capped', () {
    var s = GameSession.start(
      BoardState.fromTypes(const [
        [0],
        [],
      ]),
    );
    for (var i = 0; i < GameSession.maxHistory + 10; i++) {
      s = s.play(Move(i.isEven ? 0 : 1, i.isEven ? 1 : 0))!.$1;
    }
    var undos = 0;
    var cur = s.addUndos(1000);
    while (cur.canUndo) {
      cur = cur.undo()!;
      undos++;
    }
    expect(undos, GameSession.maxHistory);
  });
}
