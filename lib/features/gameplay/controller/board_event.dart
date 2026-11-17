import 'package:bazaar_sort/core/game_logic/game_logic.dart';

/// Something the board renderer should animate or the HUD should react to.
sealed class BoardEvent {
  const new();
}

/// A shelf was selected (its top run lifts).
final class ShelfSelected extends BoardEvent {
  const new(this.shelf);
  final int shelf;
}

/// Selection cleared without a move.
final class SelectionCleared extends BoardEvent {
  const new(this.shelf);
  final int shelf;
}

/// A legal move happened.
final class ItemsMoved extends BoardEvent {
  const new(this.outcome);
  final MoveOutcome outcome;
}

/// A tap that couldn't do anything (shake + light haptic).
final class MoveRejected extends BoardEvent {
  const new(this.shelf, this.reason);
  final int shelf;
  final MoveRejection reason;
}

/// The board changed without a move (undo, extra shelf, shuffle, restart):
/// the renderer rebuilds instantly.
final class BoardReset extends BoardEvent {
  const new(this.board, {this.reason = BoardResetReason.other});
  final BoardState board;
  final BoardResetReason reason;
}

/// Why a [BoardReset] happened (for small flourishes).
enum BoardResetReason { undo, extraShelf, shuffle, restart, other }

/// A hint is available: highlight [move].
final class HintShown extends BoardEvent {
  const new(this.move);
  final Move move;
}

/// The level is solved.
final class LevelWon extends BoardEvent {
  const new();
}
