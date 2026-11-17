import 'package:bazaar_sort/core/game_logic/game_rules.dart';
import 'package:bazaar_sort/core/level_gen/generated_level.dart';

/// Replays [level]'s stored solution with [rules] and reports whether it
/// legally ends in a won board with exactly `optimalMoves` moves.
///
/// This is a full proof of solvability that costs microseconds, so it can
/// run over every bundled level in tests and CI.
bool replaySolves(
  GeneratedLevel level, {
  GameRules rules = GameRules.standard,
}) {
  if (level.solution.length != level.optimalMoves) return false;
  var board = level.board;
  for (final move in level.solution) {
    if (!rules.isLegal(board, move)) return false;
    board = rules.apply(board, move).after;
  }
  return rules.isWon(board);
}
