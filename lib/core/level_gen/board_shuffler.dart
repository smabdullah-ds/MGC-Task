import 'package:bazaar_sort/core/game_logic/board_state.dart';
import 'package:bazaar_sort/core/game_logic/game_rules.dart';
import 'package:bazaar_sort/core/game_logic/item.dart';
import 'package:bazaar_sort/core/game_logic/shelf.dart';
import 'package:bazaar_sort/core/level_gen/seeded_random.dart';
import 'package:bazaar_sort/core/level_gen/solver.dart';

/// The Shuffle booster: re-deals the movable goods while keeping the level
/// solvable.
///
/// Locked shelves, completed shelves and frozen items stay where they are.
/// Every other item's *type* is shuffled among the remaining slots, keeping
/// each shelf's height and each slot's hidden flag. Candidates are verified
/// with the solver; the first solvable one is returned.
final class BoardShuffler {
  /// Creates a shuffler.
  const new({
    this.solver = const Solver(),
    this.limits = const SolverLimits(
      maxNodes: 60000,
      maxDuration: Duration(seconds: 2),
      fallbackWeights: <double>[3],
    ),
  });

  /// Verifier.
  final Solver solver;

  /// Per-candidate solver limits.
  final SolverLimits limits;

  /// Returns a shuffled, solvable board, or `null` if none was found in
  /// [attempts] tries (the caller should refund the booster).
  BoardState? shuffle(BoardState board, SeededRandom rng, {int attempts = 12}) {
    final slots = <(int, int)>[];
    final types = <int>[];
    for (var s = 0; s < board.shelfCount; s++) {
      if (board.isLocked(s) || board.isComplete(s)) continue;
      final items = board.shelves[s].items;
      for (var p = 0; p < items.length; p++) {
        if (items[p].isFrozen) continue;
        slots.add((s, p));
        types.add(items[p].type);
      }
    }
    if (slots.length < 2) return null;

    for (var attempt = 0; attempt < attempts; attempt++) {
      final dealt = [...types];
      rng.shuffle(dealt);
      final grid = [
        for (final shelf in board.shelves) [...shelf.items],
      ];
      for (var i = 0; i < slots.length; i++) {
        final (s, p) = slots[i];
        grid[s][p] = Item.of(dealt[i], hidden: grid[s][p].isHidden);
      }
      final candidate = BoardState(
        capacity: board.capacity,
        shelves: [
          for (var s = 0; s < board.shelfCount; s++)
            Shelf(grid[s], unlockAfter: board.shelves[s].unlockAfter),
        ],
      ).withTopsRevealed();
      if (candidate.key == board.key) continue;
      if (GameRules.standard.isWon(candidate)) continue;
      if (candidate.completedCount > board.completedCount) continue;
      if (solver.solve(candidate, limits: limits).isSolved) return candidate;
    }
    return null;
  }
}
