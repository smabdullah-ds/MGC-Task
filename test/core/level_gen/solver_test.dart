import 'dart:collection';

import 'package:bazaar_sort/core/game_logic/game_logic.dart';
import 'package:bazaar_sort/core/level_gen/solver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hand_made_boards.dart';

/// Plain breadth-first search with no heuristic and no pruning: slow but
/// obviously correct, used to cross-check the A* solver.
int bfsOptimal(BoardState start) {
  const rules = GameRules.standard;
  final seen = <String>{start.key};
  final queue = Queue<(BoardState, int)>()..add((start, 0));
  while (queue.isNotEmpty) {
    final (board, depth) = queue.removeFirst();
    if (rules.isWon(board)) return depth;
    for (final m in rules.legalMoves(board)) {
      final next = rules.apply(board, m).after;
      if (seen.add(next.key)) queue.add((next, depth + 1));
    }
  }
  return -2;
}

void main() {
  const solver = Solver();
  const rules = GameRules.standard;

  test('there are 20 hand-made boards', () {
    expect(handMadeBoards, hasLength(20));
  });

  group('hand-made boards', () {
    for (final h in handMadeBoards) {
      test('${h.name}: optimal ${h.optimal}', () {
        final result = solver.solve(h.board);
        if (h.optimal == -2) {
          expect(result.status, SolveStatus.unsolvable);
          expect(result.isSolved, isFalse);
          return;
        }
        expect(result.status, SolveStatus.solved);
        expect(result.optimal, isTrue);
        expect(result.moveCount, h.optimal);
        // The move list must actually solve the board.
        var b = h.board;
        for (final m in result.moves) {
          expect(rules.isLegal(b, m), isTrue, reason: 'illegal $m');
          b = rules.apply(b, m).after;
        }
        expect(rules.isWon(b), isTrue);
      });
    }
  });

  test('expected values agree with brute-force BFS', () {
    for (final h in handMadeBoards) {
      expect(bfsOptimal(h.board), h.optimal, reason: h.name);
    }
  });

  test('heuristic is zero on solved boards and admissible', () {
    for (final h in handMadeBoards.where((h) => h.optimal >= 0)) {
      expect(solver.heuristic(h.board), lessThanOrEqualTo(h.optimal));
    }
    expect(solver.heuristic(handMadeBoards.first.board), 0);
  });

  test('node limit reports limitReached', () {
    final board = handMadeBoards.firstWhere((h) => h.name == 'k4 bands').board;
    final r = solver.solve(
      board,
      limits: const SolverLimits(maxNodes: 3, fallbackWeights: []),
    );
    expect(r.status, SolveStatus.limitReached);
    expect(r.moves, isEmpty);
  });

  test('time limit stops the search', () {
    final board = handMadeBoards.firstWhere((h) => h.name == 'k4 bands').board;
    final r = solver.solve(
      board,
      limits: const SolverLimits(
        maxNodes: 1 << 30,
        maxDuration: Duration.zero,
        fallbackWeights: [2],
      ),
    );
    expect(r.status, isNot(SolveStatus.unsolvable));
  });

  test('weighted fallback still solves (maybe not optimally)', () {
    final board = handMadeBoards.firstWhere((h) => h.name == 'k4 mixed').board;
    final r = solver.solve(
      board,
      limits: const SolverLimits(maxNodes: 20, fallbackWeights: [5, 50]),
    );
    if (r.isSolved) {
      expect(r.optimal, isFalse);
      expect(r.moveCount, greaterThanOrEqualTo(12));
    } else {
      expect(r.status, SolveStatus.limitReached);
    }
  });

  test('hint limits are fast', () {
    final board = handMadeBoards.firstWhere((h) => h.name == 'k4 mixed').board;
    final r = solver.solve(board, limits: SolverLimits.hint);
    expect(r.isSolved, isTrue);
  });

  test('candidate pruning keeps one empty destination', () {
    final b = BoardState.fromTypes(const [
      [0, 1],
      [],
      [],
    ]);
    expect(solver.candidateMoves(b), const [Move(0, 1)]);
  });
}
