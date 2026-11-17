import 'package:bazaar_sort/core/game_logic/item.dart';
import 'package:bazaar_sort/core/game_logic/shelf.dart';
import 'package:meta/meta.dart';

/// Immutable snapshot of the board. Every move produces a new instance.
@immutable
final class BoardState {
  /// Creates a board. All shelves share the same [capacity].
  new({required Iterable<Shelf> shelves, required this.capacity})
    : assert(capacity > 0, 'capacity must be positive'),
      shelves = List<Shelf>.unmodifiable(shelves) {
    assert(
      this.shelves.every((s) => s.length <= capacity),
      'a shelf exceeds capacity',
    );
  }

  /// Convenience constructor from item types (no obstacles), bottom first.
  ///
  /// `BoardState.fromTypes([[0, 1], [1, 0], []], capacity: 2)`
  factory fromTypes(List<List<int>> shelves, {int capacity = 4}) => BoardState(
    shelves: [
      for (final s in shelves) Shelf([for (final t in s) Item.of(t)]),
    ],
    capacity: capacity,
  );

  /// Decodes JSON produced by [toJson].
  factory fromJson(Map<String, Object?> json) => BoardState(
    capacity: json['c']! as int,
    shelves: [
      for (final s in json['s']! as List<Object?>)
        Shelf.fromJson((s! as Map<Object?, Object?>).cast<String, Object?>()),
    ],
  );

  /// Shelves in display order.
  final List<Shelf> shelves;

  /// Items per full shelf.
  final int capacity;

  /// Number of shelves.
  int get shelfCount => shelves.length;

  /// Number of completed shelves.
  int get completedCount {
    var n = 0;
    for (final s in shelves) {
      if (s.isComplete(capacity)) n++;
    }
    return n;
  }

  /// Whether shelf [index] is complete.
  bool isComplete(int index) => shelves[index].isComplete(capacity);

  /// Whether shelf [index] is still locked.
  bool isLocked(int index) => shelves[index].unlockAfter > completedCount;

  /// Free slots on shelf [index].
  int freeSpace(int index) => capacity - shelves[index].length;

  /// Distinct item types on the board.
  Set<int> get itemTypes => {
    for (final s in shelves)
      for (final i in s.items) i.type,
  };

  /// Whether any item is frozen.
  bool get hasFrozen => shelves.any((s) => s.hasFrozen);

  /// Whether any item is hidden.
  bool get hasHidden => shelves.any((s) => s.items.any((i) => i.isHidden));

  /// Whether any shelf has a lock.
  bool get hasLocks => shelves.any((s) => s.unlockAfter > 0);

  /// Returns a copy with the given shelves replaced.
  BoardState withShelves(Map<int, Shelf> replacements) => BoardState(
    capacity: capacity,
    shelves: [
      for (var i = 0; i < shelves.length; i++) replacements[i] ?? shelves[i],
    ],
  );

  /// Returns a copy with one extra empty shelf appended.
  BoardState withExtraShelf() =>
      BoardState(capacity: capacity, shelves: [...shelves, Shelf.empty()]);

  /// Returns a copy where every shelf's top item is revealed.
  BoardState withTopsRevealed() {
    final changes = <int, Shelf>{};
    for (var i = 0; i < shelves.length; i++) {
      final top = shelves[i].top;
      if (top != null && top.isHidden) {
        final items = [...shelves[i].items];
        items[items.length - 1] = top.revealed();
        changes[i] = shelves[i].withItems(items);
      }
    }
    return changes.isEmpty ? this : withShelves(changes);
  }

  /// Exact key: two boards with equal keys are identical.
  String get key => '$capacity|${shelves.map((s) => s.key).join('|')}';

  /// Key that treats boards differing only in shelf order as equal.
  ///
  /// Shelf order matters while frozen items exist (thawing depends on
  /// neighbouring shelves), so then the exact order is kept.
  String get canonicalKey {
    if (hasFrozen) return key;
    final keys = shelves.map((s) => s.key).toList()..sort();
    return '$capacity|${keys.join('|')}';
  }

  /// JSON encoding: `{"c": capacity, "s": [shelf, ...]}`.
  Map<String, Object?> toJson() => <String, Object?>{
    'c': capacity,
    's': [for (final s in shelves) s.toJson()],
  };

  @override
  bool operator ==(Object other) => other is BoardState && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'BoardState(c=$capacity, ${shelves.join(' ')})';
}
