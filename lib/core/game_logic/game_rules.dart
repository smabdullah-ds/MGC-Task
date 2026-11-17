import 'package:bazaar_sort/core/game_logic/board_state.dart';
import 'package:bazaar_sort/core/game_logic/move.dart';
import 'package:bazaar_sort/core/game_logic/rules/frozen_items_rule.dart';
import 'package:bazaar_sort/core/game_logic/rules/hidden_items_rule.dart';
import 'package:bazaar_sort/core/game_logic/rules/locked_shelves_rule.dart';
import 'package:bazaar_sort/core/game_logic/rules/rule_module.dart';

/// The rules of Bazaar Sort: move validation, application, win and stuck
/// detection. Stateless and pure; safe to share across isolates.
final class GameRules {
  /// Creates rules with the given obstacle [modules].
  const new({this.modules = allModules});

  /// Every obstacle module. They are no-ops on boards without that obstacle,
  /// so using all of them is always correct.
  static const List<RuleModule> allModules = <RuleModule>[
    LockedShelvesRule(),
    FrozenItemsRule(),
    HiddenItemsRule(),
  ];

  /// Shared default instance.
  static const GameRules standard = GameRules();

  /// Active obstacle modules.
  final List<RuleModule> modules;

  /// Number of items that would leave shelf [index] in a move: the top run of
  /// one type, stopping at hidden or frozen items. 0 if nothing can be taken.
  int movableRun(BoardState board, int index) {
    if (_pickRejection(board, index) != null) return 0;
    final items = board.shelves[index].items;
    final type = items.last.type;
    var run = 1;
    for (var i = items.length - 2; i >= 0; i--) {
      final item = items[i];
      if (item.type != type || modules.any((m) => m.stopsRun(item))) break;
      run++;
    }
    return run;
  }

  MoveRejection? _pickRejection(BoardState board, int index) {
    final shelf = board.shelves[index];
    if (shelf.isEmpty) return MoveRejection.sourceEmpty;
    if (shelf.isComplete(board.capacity)) return MoveRejection.sourceComplete;
    for (final m in modules) {
      final r = m.checkPick(board, index);
      if (r != null) return r;
    }
    return null;
  }

  /// Whether shelf [index] can be picked up from (for selection feedback).
  bool canPick(BoardState board, int index) =>
      index >= 0 &&
      index < board.shelfCount &&
      _pickRejection(board, index) == null;

  /// Why [move] is illegal, or `null` if it is legal.
  MoveRejection? validate(BoardState board, Move move) {
    final n = board.shelfCount;
    if (move.from < 0 || move.from >= n || move.to < 0 || move.to >= n) {
      return MoveRejection.outOfRange;
    }
    if (move.from == move.to) return MoveRejection.sameShelf;
    final pick = _pickRejection(board, move.from);
    if (pick != null) return pick;
    for (final m in modules) {
      final r = m.checkDrop(board, move.to);
      if (r != null) return r;
    }
    if (board.freeSpace(move.to) <= 0) return MoveRejection.destinationFull;
    final destTop = board.shelves[move.to].top;
    final srcTop = board.shelves[move.from].top!;
    if (destTop != null && destTop.type != srcTop.type) {
      return MoveRejection.typeMismatch;
    }
    return null;
  }

  /// Whether [move] is legal.
  bool isLegal(BoardState board, Move move) => validate(board, move) == null;

  /// All legal moves, in a stable order (by source, then destination).
  List<Move> legalMoves(BoardState board) {
    final moves = <Move>[];
    for (var from = 0; from < board.shelfCount; from++) {
      if (_pickRejection(board, from) != null) continue;
      for (var to = 0; to < board.shelfCount; to++) {
        if (to != from && validate(board, Move(from, to)) == null) {
          moves.add(Move(from, to));
        }
      }
    }
    return moves;
  }

  /// Applies a legal [move]. Throws [ArgumentError] for illegal moves.
  MoveOutcome apply(BoardState board, Move move) {
    final rejection = validate(board, move);
    if (rejection != null) {
      throw ArgumentError.value(move, 'move', 'illegal: ${rejection.name}');
    }
    final src = board.shelves[move.from];
    final dst = board.shelves[move.to];
    final count = _min(movableRun(board, move.from), board.freeSpace(move.to));
    final moving = src.items.sublist(src.length - count);
    var next = board.withShelves({
      move.from: src.withItems(src.items.sublist(0, src.length - count)),
      move.to: dst.withItems([...dst.items, ...moving]),
    });
    final completed = next.isComplete(move.to) ? move.to : null;

    final thawed = <int>[];
    final revealed = <int>[];
    for (final m in modules) {
      final effect = m.afterMove(next, move: move, completedShelf: completed);
      next = effect.board;
      thawed.addAll(effect.thawed);
      revealed.addAll(effect.revealed);
    }

    final unlocked = <int>[
      if (completed != null)
        for (var i = 0; i < next.shelfCount; i++)
          if (board.isLocked(i) && !next.isLocked(i)) i,
    ];

    return MoveOutcome(
      before: board,
      after: next,
      move: move,
      count: count,
      itemType: moving.first.type,
      completedShelf: completed,
      thawedShelves: thawed,
      revealedShelves: revealed,
      unlockedShelves: unlocked,
    );
  }

  /// Whether every non-empty shelf is complete.
  bool isWon(BoardState board) {
    for (var i = 0; i < board.shelfCount; i++) {
      final s = board.shelves[i];
      if (!s.isEmpty && !s.isComplete(board.capacity)) return false;
    }
    return true;
  }

  /// Whether the board is not won and no legal move exists.
  bool isStuck(BoardState board) {
    if (isWon(board)) return false;
    for (var from = 0; from < board.shelfCount; from++) {
      if (_pickRejection(board, from) != null) continue;
      for (var to = 0; to < board.shelfCount; to++) {
        if (to != from && validate(board, Move(from, to)) == null) {
          return false;
        }
      }
    }
    return true;
  }

  static int _min(int a, int b) => a < b ? a : b;
}
