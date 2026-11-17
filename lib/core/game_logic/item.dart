/// A single good on a shelf, packed into an `int` for speed (the solver
/// creates millions of these).
///
/// Bit layout: bits 0–7 hold the item type (0–255), bit 8 is *hidden*,
/// bit 9 is *frozen*. The packed value is also the JSON encoding used in
/// `assets/levels/*.json`.
extension type const Item(int bits) {
  /// Creates an item of [type] with optional obstacle flags.
  factory of(int type, {bool hidden = false, bool frozen = false}) {
    assert(type >= 0 && type <= typeMask, 'type out of range: $type');
    return Item(type | (hidden ? hiddenFlag : 0) | (frozen ? frozenFlag : 0));
  }

  /// Mask for the type bits.
  static const int typeMask = 0xFF;

  /// Flag set when the item is shown as "?".
  static const int hiddenFlag = 0x100;

  /// Flag set when the item is frozen in place.
  static const int frozenFlag = 0x200;

  /// The item type (0 … K-1).
  int get type => bits & typeMask;

  /// Whether the item is hidden from the player.
  bool get isHidden => bits & hiddenFlag != 0;

  /// Whether the item is frozen.
  bool get isFrozen => bits & frozenFlag != 0;

  /// This item with the hidden flag cleared.
  Item revealed() => Item(bits & ~hiddenFlag);

  /// This item with the frozen flag cleared.
  Item thawed() => Item(bits & ~frozenFlag);

  /// Whether this and [other] are the same type (flags ignored).
  bool sameType(Item other) => type == other.type;
}
