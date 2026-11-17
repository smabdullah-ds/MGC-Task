import 'package:bazaar_sort/core/game_logic/board_state.dart';
import 'package:bazaar_sort/core/game_logic/item.dart';
import 'package:bazaar_sort/core/game_logic/move.dart';
import 'package:bazaar_sort/core/game_logic/rules/rule_module.dart';

/// Level 40+: a shelf with `unlockAfter = X` can't be used until X shelves
/// have been completed. Its contents (if any) stay put until then.
final class LockedShelvesRule implements RuleModule {
  /// Creates the rule.
  const new();

  @override
  String get id => 'locked';

  @override
  MoveRejection? checkPick(BoardState board, int shelf) =>
      board.isLocked(shelf) ? MoveRejection.sourceLocked : null;

  @override
  MoveRejection? checkDrop(BoardState board, int shelf) =>
      board.isLocked(shelf) ? MoveRejection.destinationLocked : null;

  @override
  bool stopsRun(Item item) => false;

  @override
  RuleEffect afterMove(
    BoardState board, {
    required Move move,
    required int? completedShelf,
  }) => RuleEffect(board);
}
