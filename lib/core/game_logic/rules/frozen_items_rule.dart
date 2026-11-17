import 'package:bazaar_sort/core/game_logic/board_state.dart';
import 'package:bazaar_sort/core/game_logic/item.dart';
import 'package:bazaar_sort/core/game_logic/move.dart';
import 'package:bazaar_sort/core/game_logic/rules/rule_module.dart';
import 'package:bazaar_sort/core/game_logic/shelf.dart';

/// Level 60+: frozen items can't be moved. Completing a shelf thaws every
/// frozen item on the neighbouring shelves (index − 1 and index + 1).
///
/// Items may still be placed on top of a frozen item if the type matches.
final class FrozenItemsRule implements RuleModule {
  /// Creates the rule.
  const new();

  @override
  String get id => 'frozen';

  @override
  MoveRejection? checkPick(BoardState board, int shelf) =>
      (board.shelves[shelf].top?.isFrozen ?? false)
      ? MoveRejection.sourceFrozen
      : null;

  @override
  MoveRejection? checkDrop(BoardState board, int shelf) => null;

  @override
  bool stopsRun(Item item) => item.isFrozen;

  @override
  RuleEffect afterMove(
    BoardState board, {
    required Move move,
    required int? completedShelf,
  }) {
    if (completedShelf == null) return RuleEffect(board);
    final changes = <int, Shelf>{};
    final thawed = <int>[];
    for (final n in [completedShelf - 1, completedShelf + 1]) {
      if (n < 0 || n >= board.shelfCount) continue;
      final shelf = board.shelves[n];
      if (!shelf.hasFrozen) continue;
      changes[n] = shelf.withItems([for (final i in shelf.items) i.thawed()]);
      thawed.add(n);
    }
    if (thawed.isEmpty) return RuleEffect(board);
    return RuleEffect(board.withShelves(changes), thawed: thawed);
  }
}
