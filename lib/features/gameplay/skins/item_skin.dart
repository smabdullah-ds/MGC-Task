import 'dart:ui';

/// Draws goods. The only seam between game logic and art: swap the
/// implementation (e.g. a sprite-sheet skin) to drop in real art with no
/// logic changes. Item types are plain ints 0…K-1.
abstract interface class ItemSkin {
  /// Number of distinct goods this skin can draw.
  int get typeCount;

  /// Human-readable name of [type] (accessibility, debug).
  String nameOf(int type);

  /// Main colour of [type] (particles, highlights).
  Color colorOf(int type);

  /// Paints [type] inside [rect]. With [colorblind] the item also carries a
  /// unique symbol so it never relies on colour alone.
  void paintItem(
    Canvas canvas,
    Rect rect,
    int type, {
    required bool colorblind,
  });

  /// Paints a hidden ("?") item inside [rect].
  void paintHidden(Canvas canvas, Rect rect);

  /// Paints the ice overlay for a frozen item.
  void paintFrozen(Canvas canvas, Rect rect);
}
