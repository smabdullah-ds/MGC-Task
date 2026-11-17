import 'package:bazaar_sort/core/game_logic/board_state.dart';
import 'package:bazaar_sort/core/game_logic/item.dart';
import 'package:bazaar_sort/core/game_logic/move.dart';

/// A pluggable obstacle rule. Each obstacle (hidden, locked, frozen) is one
/// module so it can be introduced, tuned and tested on its own.
///
/// Modules only *restrict* moves or *post-process* the board after a move;
/// the base rules (matching tops, capacity) live in `GameRules`.
abstract interface class RuleModule {
  /// Stable id used in level difficulty tags.
  String get id;

  /// Returns a rejection if items may not be taken from [shelf].
  MoveRejection? checkPick(BoardState board, int shelf);

  /// Returns a rejection if items may not be dropped on [shelf].
  MoveRejection? checkDrop(BoardState board, int shelf);

  /// Whether [item] (below the top) ends the movable run.
  bool stopsRun(Item item);

  /// Applies follow-up effects after the base move. [completedShelf] is the
  /// destination index when the move completed it.
  RuleEffect afterMove(
    BoardState board, {
    required Move move,
    required int? completedShelf,
  });
}

/// Board changes produced by [RuleModule.afterMove].
final class RuleEffect {
  /// Creates an effect.
  const new(
    this.board, {
    this.thawed = const <int>[],
    this.revealed = const <int>[],
  });

  /// Board after the effect.
  final BoardState board;

  /// Shelves whose frozen items thawed.
  final List<int> thawed;

  /// Shelves whose top was revealed.
  final List<int> revealed;
}
