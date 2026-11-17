import 'package:bazaar_sort/core/game_logic/item.dart';
import 'package:meta/meta.dart';

/// One shelf (tube). Items are ordered bottom → top. Immutable.
@immutable
final class Shelf {
  /// Creates a shelf. [unlockAfter] > 0 means the shelf stays locked until
  /// that many shelves have been completed on the board.
  new(Iterable<Item> items, {this.unlockAfter = 0})
    : items = List<Item>.unmodifiable(items);

  /// An empty, unlocked shelf.
  new empty() : this(const <Item>[]);

  /// Decodes a shelf from JSON (`{"i": [packed items], "u": unlockAfter}`).
  factory fromJson(Map<String, Object?> json) => Shelf([
    for (final v in json['i']! as List<Object?>) Item(v! as int),
  ], unlockAfter: (json['u'] as int?) ?? 0);

  /// Items, bottom first.
  final List<Item> items;

  /// Number of completed shelves required to unlock this shelf (0 = open).
  final int unlockAfter;

  /// Number of items.
  int get length => items.length;

  /// Whether the shelf holds no items.
  bool get isEmpty => items.isEmpty;

  /// The top item, or `null` when empty.
  Item? get top => items.isEmpty ? null : items.last;

  /// Whether any item on this shelf is frozen.
  bool get hasFrozen => items.any((i) => i.isFrozen);

  /// Whether the shelf is full with a single item type.
  bool isComplete(int capacity) {
    if (items.length != capacity || capacity == 0) return false;
    final t = items.first.type;
    for (final item in items) {
      if (item.type != t) return false;
    }
    return true;
  }

  /// Returns a copy with [items] replaced.
  Shelf withItems(Iterable<Item> items) =>
      Shelf(items, unlockAfter: unlockAfter);

  /// JSON encoding. `u` is omitted when 0 to keep level files small.
  Map<String, Object?> toJson() => <String, Object?>{
    'i': [for (final i in items) i.bits],
    if (unlockAfter > 0) 'u': unlockAfter,
  };

  /// Compact, stable string used for hashing states.
  String get key {
    final b = StringBuffer(unlockAfter > 0 ? 'L$unlockAfter:' : '');
    for (final i in items) {
      b
        ..write(i.bits.toRadixString(36))
        ..write(',');
    }
    return b.toString();
  }

  @override
  String toString() =>
      'Shelf(${items.map((i) => i.type).join(',')}'
      '${unlockAfter > 0 ? ' lock=$unlockAfter' : ''})';
}
