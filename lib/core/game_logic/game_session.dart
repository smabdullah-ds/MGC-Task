import 'package:bazaar_sort/core/game_logic/board_state.dart';
import 'package:bazaar_sort/core/game_logic/game_rules.dart';
import 'package:bazaar_sort/core/game_logic/move.dart';

/// Where a session stands.
enum SessionStatus {
  /// Moves are possible.
  playing,

  /// Every shelf is sorted.
  won,

  /// No legal move exists.
  stuck,

  /// Move-limited level and the limit is used up.
  outOfMoves,
}

/// One snapshot on the undo stack.
final class _Snapshot {
  const new(this.board, this.moves);
  final BoardState board;
  final int moves;
}

/// The state of one level attempt: board, undo history, move counter and
/// per-level booster allowances. Immutable — every action returns a new
/// session.
final class GameSession {
  new _({
    required this.board,
    required this.rules,
    required this.movesMade,
    required this.moveLimit,
    required this.undosLeft,
    required this.extraShelfUsed,
    required this._history,
  });

  /// Starts a session on [board].
  factory start(
    BoardState board, {
    GameRules rules = GameRules.standard,
    int? moveLimit,
    int freeUndos = 3,
  }) => GameSession._(
    board: board.withTopsRevealed(),
    rules: rules,
    movesMade: 0,
    moveLimit: moveLimit,
    undosLeft: freeUndos,
    extraShelfUsed: false,
    history: const <_Snapshot>[],
  );

  /// Maximum undo snapshots kept.
  static const int maxHistory = 64;

  /// Current board.
  final BoardState board;

  /// Rules in force.
  final GameRules rules;

  /// Moves made so far (undo gives a move back).
  final int movesMade;

  /// Maximum moves for move-limited levels, else `null`.
  final int? moveLimit;

  /// Undo charges remaining.
  final int undosLeft;

  /// Whether the extra-shelf booster was used (once per level).
  final bool extraShelfUsed;

  final List<_Snapshot> _history;

  /// Whether there is a move to undo.
  bool get hasHistory => _history.isNotEmpty;

  /// Whether undo is possible right now.
  bool get canUndo => hasHistory && undosLeft > 0;

  /// Moves left on move-limited levels, else `null`.
  int? get movesLeft => moveLimit == null ? null : moveLimit! - movesMade;

  /// Current status.
  SessionStatus get status {
    if (rules.isWon(board)) return SessionStatus.won;
    if (moveLimit != null && movesMade >= moveLimit!) {
      return SessionStatus.outOfMoves;
    }
    if (rules.isStuck(board)) return SessionStatus.stuck;
    return SessionStatus.playing;
  }

  /// Applies [move]. Returns `null` (and leaves the session unchanged) when
  /// the move is illegal or the session is over.
  (GameSession, MoveOutcome)? play(Move move) {
    if (status != SessionStatus.playing) return null;
    if (!rules.isLegal(board, move)) return null;
    final outcome = rules.apply(board, move);
    final history = [..._history, _Snapshot(board, movesMade)];
    if (history.length > maxHistory) history.removeAt(0);
    return (
      _copy(board: outcome.after, movesMade: movesMade + 1, history: history),
      outcome,
    );
  }

  /// Reverts the last move, consuming an undo charge. `null` if impossible.
  GameSession? undo() {
    if (!canUndo) return null;
    final last = _history.last;
    return _copy(
      board: last.board,
      movesMade: last.moves,
      undosLeft: undosLeft - 1,
      history: _history.sublist(0, _history.length - 1),
    );
  }

  /// Adds undo charges (rewarded ad / coins).
  GameSession addUndos(int count) => _copy(undosLeft: undosLeft + count);

  /// Adds one empty shelf. `null` if already used this level.
  GameSession? addExtraShelf() {
    if (extraShelfUsed) return null;
    return _copy(board: board.withExtraShelf(), extraShelfUsed: true);
  }

  /// Raises the move limit by [count] (extra moves on fail).
  GameSession addMoves(int count) =>
      moveLimit == null ? this : _copy(moveLimit: moveLimit! + count);

  /// Replaces the board (shuffle booster). Clears the undo history because
  /// earlier states are no longer reachable.
  GameSession replaceBoard(BoardState newBoard) =>
      _copy(board: newBoard.withTopsRevealed(), history: const <_Snapshot>[]);

  GameSession _copy({
    BoardState? board,
    int? movesMade,
    int? moveLimit,
    int? undosLeft,
    bool? extraShelfUsed,
    List<_Snapshot>? history,
  }) => GameSession._(
    board: board ?? this.board,
    rules: rules,
    movesMade: movesMade ?? this.movesMade,
    moveLimit: moveLimit ?? this.moveLimit,
    undosLeft: undosLeft ?? this.undosLeft,
    extraShelfUsed: extraShelfUsed ?? this.extraShelfUsed,
    history: history ?? _history,
  );
}
