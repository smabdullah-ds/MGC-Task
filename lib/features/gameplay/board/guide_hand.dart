import 'dart:math' as math;
import 'dart:ui';

import 'package:bazaar_sort/app/palette.dart';
import 'package:flame/components.dart';

/// Pointing hand used by tutorial levels. Bobs above its target.
class GuideHand extends PositionComponent {
  /// Creates a hand of [side] logical pixels.
  new({required double side})
    : super(size: Vector2.all(side), anchor: Anchor.topCenter, priority: 90);

  double _t = 0;
  final Vector2 _target = Vector2.zero();

  /// Points at [target] (top-centre of a shelf).
  void pointAt(Vector2 target) => _target.setFrom(target);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    position.setValues(
      _target.x,
      _target.y - size.y * 0.15 + math.sin(_t * 5) * size.y * 0.12,
    );
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final skin = Paint()..color = Palette.ivory;
    final outline = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeJoin = StrokeJoin.round;
    final finger = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.4, 0, w * 0.2, h * 0.55),
      Radius.circular(w * 0.1),
    );
    final palm = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.38, w * 0.56, h * 0.5),
      Radius.circular(w * 0.18),
    );
    canvas
      ..drawCircle(
        Offset(w * 0.5, -h * 0.05),
        w * 0.16,
        Paint()..color = Palette.saffron.withValues(alpha: 0.5),
      )
      ..drawRRect(palm, skin)
      ..drawRRect(palm, outline)
      ..drawRRect(finger, skin)
      ..drawRRect(finger, outline);
  }
}
