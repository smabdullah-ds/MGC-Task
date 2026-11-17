import 'package:bazaar_sort/core/game_logic/board_state.dart';
import 'package:meta/meta.dart';

/// A player intent: move the top run from shelf [from] to shelf [to].
@immutable
final class Move {
  /// Creates a move.
  const new(this.from, this.to);

  /// Decodes `[from, to]`.
  factory fromJson(List<Object?> json) =>
      Move(json[0]! as int, json[1]! as int);

  /// Source shelf index.
  final int from;

  /// Destination shelf index.
  final int to;

  /// JSON encoding `[from, to]`.
  List<int> toJson() => [from, to];

  @override
  bool operator ==(Object other) =>
      other is Move && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '$from→$to';
}

/// Everything that happened when a move was applied; the renderer uses it to
/// drive animations and effects.
final class MoveOutcome {
  /// Creates an outcome.
  const new({
    required this.before,
    required this.after,
    required this.move,
    required this.count,
    required this.itemType,
    this.completedShelf,
    this.thawedShelves = const <int>[],
    this.revealedShelves = const <int>[],
    this.unlockedShelves = const <int>[],
  });

  /// Board before the move.
  final BoardState before;

  /// Board after the move.
  final BoardState after;

  /// The move applied.
  final Move move;

  /// Number of items moved.
  final int count;

  /// Type of the moved items.
  final int itemType;

  /// Destination index if the move completed it.
  final int? completedShelf;

  /// Shelves whose frozen items thawed.
  final List<int> thawedShelves;

  /// Shelves whose new top item was revealed.
  final List<int> revealedShelves;

  /// Shelves unlocked by this move's completion.
  final List<int> unlockedShelves;
}

/// Why a move was rejected (for feedback such as the shake animation).
enum MoveRejection {
  sameShelf,
  outOfRange,
  sourceEmpty,
  sourceLocked,
  sourceComplete,
  sourceFrozen,
  destinationLocked,
  destinationFull,
  typeMismatch,
}
