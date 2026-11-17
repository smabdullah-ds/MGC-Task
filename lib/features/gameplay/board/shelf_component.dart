import 'dart:math' as math;
import 'dart:ui';

import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/features/gameplay/board/picture_cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

/// A wooden shelf (tube). Draws itself, its lock/hint/complete states and
/// forwards taps and drags to the board.
class ShelfComponent extends PositionComponent
    with TapCallbacks, DragCallbacks {
  /// Creates a shelf at [index].
  new({
    required this.index,
    required this.onTap,
    required this.onDropAt,
    required Rect rect,
    required this.hitRect,
  }) : super(
         position: Vector2(rect.left, rect.top),
         size: Vector2(rect.width, rect.height),
       );

  /// Board index.
  final int index;

  /// Called when tapped.
  final void Function(int index) onTap;

  /// Called when a drag that started here ends at a global position.
  final void Function(int from, Vector2 globalEnd) onDropAt;

  /// Hit area in game coordinates (≥ 48 dp, includes lifted items).
  Rect hitRect;

  /// Shelves still needed before unlocking (0 = unlocked).
  int locksRemaining = 0;

  /// Whether the shelf is completed (glows).
  bool completed = false;

  /// Whether this shelf is part of the shown hint.
  bool hinted = false;

  double _time = 0;
  double _shakeT = 1;
  double _celebrateT = 1;
  final Vector2 _dragPos = Vector2.zero();

  /// Plays the invalid-move shake.
  void shake() => _shakeT = 0;

  /// Plays the completion glow burst.
  void celebrate() => _celebrateT = 0;

  /// Moves/resizes the shelf to [rect].
  void relayout(Rect rect, Rect hit) {
    position.setValues(rect.left, rect.top);
    size.setValues(rect.width, rect.height);
    hitRect = hit;
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    final global = point + position;
    return hitRect.contains(Offset(global.x, global.y));
  }

  @override
  void onTapUp(TapUpEvent event) => onTap(index);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragPos.setFrom(event.localPosition + position);
    onTap(index);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _dragPos.add(event.localDelta);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    onDropAt(index, _dragPos.clone());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_shakeT < 1) _shakeT = math.min(1, _shakeT + dt / 0.3);
    if (_celebrateT < 1) _celebrateT = math.min(1, _celebrateT + dt / 0.6);
  }

  @override
  void onRemove() {
    _lockText?.dispose();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    if (_shakeT < 1) {
      canvas.translate(
        math.sin(_shakeT * math.pi * 6) * size.x * 0.06 * (1 - _shakeT),
        0,
      );
    }
    final w = size.x;
    final h = size.y;
    final radius = Radius.circular(w * 0.28);
    final outer = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, w, h),
      bottomLeft: radius,
      bottomRight: radius,
      topLeft: Radius.circular(w * 0.12),
      topRight: Radius.circular(w * 0.12),
    );

    if (hinted) {
      final pulse = 0.5 + 0.5 * math.sin(_time * 6);
      canvas.drawRRect(
        outer.inflate(w * 0.08 + pulse * w * 0.04),
        Paint()
          ..color = Palette.saffron.withValues(alpha: 0.35 + pulse * 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08),
      );
    }
    if (completed || _celebrateT < 1) {
      final glow = completed ? 0.45 : 0.0;
      final burst = _celebrateT < 1 ? math.sin(_celebrateT * math.pi) : 0.0;
      canvas.drawRRect(
        outer.inflate(w * 0.06 + burst * w * 0.12),
        Paint()
          ..color = const Color(0xFFFFE08A)
              .withValues(alpha: glow + burst * 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.1),
      );
    }

    canvas.drawPicture(
      PictureCache.board.get(
        'shelf:${w.toStringAsFixed(1)}x${h.toStringAsFixed(1)}',
        Size(w, h),
        (c) => _paintWood(c, w, h, outer),
      ),
    );

    if (locksRemaining > 0) _renderLock(canvas, w, h);
  }

  static void _paintWood(Canvas c, double w, double h, RRect outer) {
    // Wood frame and darker back panel.
    c
      ..drawRRect(
        outer,
        Paint()
          ..shader = Gradient.linear(
            Offset.zero,
            Offset(w, 0),
            [Palette.wood, const Color(0xFFA9743D), Palette.wood],
            [0, 0.5, 1],
          ),
      )
      ..drawRRect(
        outer.deflate(w * 0.07),
        Paint()
          ..shader = Gradient.linear(Offset.zero, Offset(0, h), [
            const Color(0xFF4A2C14),
            const Color(0xFF6B4423),
          ]),
      );
    // Shelf boards between slots.
    final board = Paint()..color = const Color(0x33000000);
    for (var y = h * 0.25; y < h * 0.9; y += h * 0.22) {
      c.drawLine(Offset(w * 0.1, y), Offset(w * 0.9, y), board);
    }
    // Front lip.
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w * 0.04, h - w * 0.2, w * 1.08, w * 0.2),
        Radius.circular(w * 0.08),
      ),
      Paint()..color = Palette.woodDark,
    );
  }

  TextPainter? _lockText;
  int _lockTextValue = -1;
  double _lockTextSize = 0;

  void _renderLock(Canvas canvas, double w, double h) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h),
        Radius.circular(w * 0.2),
      ),
      Paint()..color = const Color(0x99000000),
    );
    final c = Offset(w / 2, h / 2);
    final body = Rect.fromCenter(center: c, width: w * 0.5, height: w * 0.42);
    canvas
      ..drawArc(
        Rect.fromCenter(
          center: c.translate(0, -w * 0.2),
          width: w * 0.34,
          height: w * 0.4,
        ),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = Palette.sand
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.07,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(body, Radius.circular(w * 0.06)),
        Paint()..color = Palette.saffron,
      );
    if (_lockText == null ||
        _lockTextValue != locksRemaining ||
        _lockTextSize != w) {
      _lockText?.dispose();
      _lockText = TextPainter(
        text: TextSpan(
          text: '$locksRemaining',
          style: TextStyle(
            color: Palette.ink,
            fontSize: w * 0.28,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _lockTextValue = locksRemaining;
      _lockTextSize = w;
    }
    final tp = _lockText!;
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }
}
