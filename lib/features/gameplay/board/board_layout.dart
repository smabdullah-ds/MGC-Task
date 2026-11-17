import 'dart:math' as math;
import 'dart:ui';

/// Where every shelf and item slot sits on screen. Pure geometry so it can
/// be unit-tested without Flame.
///
/// Shelves are laid out in up to three centred rows, sized to fill the
/// available area while keeping every shelf at least a 48 dp tap target.
final class BoardLayout {
  new _(this.shelfRects, this.itemSize, this.capacity, this.bounds);

  /// Computes a layout for [shelfCount] shelves of [capacity] items in
  /// [area].
  factory compute({
    required Size area,
    required int shelfCount,
    required int capacity,
    double minTapTarget = 48,
  }) {
    final rows = shelfCount <= 5
        ? 1
        : shelfCount <= 12
        ? 2
        : 3;
    final perRow = (shelfCount / rows).ceil();
    const gapRatio = 0.28; // gap between shelves relative to shelf width
    const padRatio = 0.12; // inner padding relative to item size

    // Width-bound and height-bound shelf sizes; take the smaller.
    final widthBound = area.width / (perRow + (perRow + 1) * gapRatio);
    final rowGap = area.height * 0.06;
    final itemFromHeight =
        (area.height - rowGap * (rows + 1)) /
        rows /
        (capacity + 2 * padRatio + 0.6);
    final itemFromWidth = widthBound / (1 + 2 * padRatio);
    final double item = math.max(
      math.min(itemFromHeight, math.min(itemFromWidth, 96)),
      minTapTarget * 0.6,
    );
    final shelfW = item * (1 + 2 * padRatio);
    final shelfH = item * (capacity + 2 * padRatio) + item * 0.3;
    final gap = shelfW * gapRatio;

    final totalH = rows * shelfH + (rows - 1) * rowGap * 1.6;
    final top = (area.height - totalH) / 2;
    final rects = <Rect>[];
    var index = 0;
    for (var r = 0; r < rows; r++) {
      final inRow = math.min(perRow, shelfCount - index);
      final rowW = inRow * shelfW + (inRow - 1) * gap;
      final left = (area.width - rowW) / 2;
      final y = top + r * (shelfH + rowGap * 1.6);
      for (var i = 0; i < inRow; i++) {
        rects.add(Rect.fromLTWH(left + i * (shelfW + gap), y, shelfW, shelfH));
        index++;
      }
    }
    return BoardLayout._(rects, item, capacity, Offset.zero & area);
  }

  /// Shelf rectangles in board index order.
  final List<Rect> shelfRects;

  /// Side of an item's square.
  final double itemSize;

  /// Items per shelf.
  final int capacity;

  /// Area the layout was computed for.
  final Rect bounds;

  /// Rect of the item at [slot] (0 = bottom) on [shelf].
  Rect itemRect(int shelf, int slot) {
    final s = shelfRects[shelf];
    final pad = itemSize * 0.12;
    final bottom = s.bottom - pad - itemSize * 0.3;
    return Rect.fromLTWH(
      s.left + pad,
      bottom - (slot + 1) * itemSize,
      itemSize,
      itemSize,
    );
  }

  /// How far a selected run lifts.
  double get liftHeight => itemSize * 0.55;

  /// Hit area of [shelf]: its rect grown to at least [minTapTarget] and
  /// extended upwards to cover lifted items.
  Rect hitRect(int shelf, {double minTapTarget = 48}) {
    final r = shelfRects[shelf];
    final growX = math.max(0, (minTapTarget - r.width) / 2).toDouble();
    return Rect.fromLTRB(
      r.left - growX - itemSize * 0.1,
      r.top - liftHeight - itemSize * 0.2,
      r.right + growX + itemSize * 0.1,
      r.bottom + itemSize * 0.1,
    );
  }

  /// Shelf under [point], or `null`.
  int? shelfAt(Offset point) {
    for (var i = 0; i < shelfRects.length; i++) {
      if (hitRect(i).contains(point)) return i;
    }
    return null;
  }
}
