import 'package:bazaar_sort/core/game_logic/board_state.dart';
import 'package:bazaar_sort/core/game_logic/item.dart';
import 'package:bazaar_sort/core/game_logic/move.dart';
import 'package:bazaar_sort/core/game_logic/rules/rule_module.dart';

/// Level 20+: some items show as "?" until they become the top of their
/// shelf. A hidden item never belongs to the movable run, so the player only
/// ever moves goods they can see.
final class HiddenItemsRule implements RuleModule {
  /// Creates the rule.
  const new();

  @override
  String get id => 'hidden';

  @override
  MoveRejection? checkPick(BoardState board, int shelf) => null;

  @override
  MoveRejection? checkDrop(BoardState board, int shelf) => null;

  @override
  bool stopsRun(Item item) => item.isHidden;

  @override
  RuleEffect afterMove(
    BoardState board, {
    required Move move,
    required int? completedShelf,
  }) {
    final source = board.shelves[move.from];
    final top = source.top;
    if (top == null || !top.isHidden) return RuleEffect(board);
    final items = [...source.items];
    items[items.length - 1] = top.revealed();
    return RuleEffect(
      board.withShelves({move.from: source.withItems(items)}),
      revealed: [move.from],
    );
  }
}
