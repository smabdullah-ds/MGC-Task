import 'dart:math' as math;
import 'dart:ui';

import 'package:bazaar_sort/core/game_logic/item.dart';
import 'package:bazaar_sort/features/gameplay/skins/item_skin.dart';
import 'package:flame/components.dart';

/// One good on the board. Positioned by its centre; animates itself with a
/// small built-in tween so moves are predictable and cheap (no allocations
/// per frame).
class ItemComponent extends PositionComponent {
  /// Creates an item of [item] at [center] with side [side].
  new({
    required this.item,
    required this.skin,
    required this.colorblind,
    required Vector2 center,
    required double side,
  }) : super(position: center, size: Vector2.all(side), anchor: Anchor.center);

  /// What is drawn (flags may change on reveal/thaw).
  Item item;

  /// Art.
  final ItemSkin skin;

  /// Whether colourblind symbols are shown.
  bool Function() colorblind;

  final Vector2 _from = Vector2.zero();
  final Vector2 _to = Vector2.zero();
  final Vector2 _ctrl = Vector2.zero();
  double _t = 1;
  double _duration = 0;
  double _delay = 0;
  bool _arc = false;
  void Function()? _onArrive;

  double _popT = 1;
  double _shakeT = 1;

  /// Whether a move animation is running.
  bool get isAnimating => _t < 1 || _delay > 0;

  /// Animates to [target]. With [arc] the path is a quadratic curve that
  /// rises above both ends, like an item tossed between shelves.
  void moveTo(
    Vector2 target, {
    double duration = 0.25,
    bool arc = false,
    double delay = 0,
    void Function()? onArrive,
  }) {
    _from.setFrom(position);
    _to.setFrom(target);
    _arc = arc;
    if (arc) {
      final lift = math.max(size.y * 1.6, (_from - _to).length * 0.35);
      _ctrl.setValues((_from.x + _to.x) / 2, math.min(_from.y, _to.y) - lift);
    }
    _duration = duration;
    _delay = delay;
    _t = duration <= 0 ? 1 : 0;
    _onArrive = onArrive;
    if (_t >= 1) {
      position.setFrom(_to);
      _fireArrive();
    }
  }

  /// Jumps to [target] with no animation.
  void snapTo(Vector2 target) {
    _t = 1;
    _delay = 0;
    position.setFrom(target);
  }

  /// Plays the completion "pop".
  void pop({double delay = 0}) => _popT = -delay / 0.3;

  /// Plays the invalid-move shake.
  void shake() => _shakeT = 0;

  void _fireArrive() {
    final cb = _onArrive;
    _onArrive = null;
    cb?.call();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_delay > 0) {
      _delay -= dt;
      return;
    }
    if (_t < 1) {
      _t = math.min(1, _t + dt / _duration);
      final e = _easeInOut(_t);
      if (_arc) {
        final u = 1 - e;
        position.setValues(
          u * u * _from.x + 2 * u * e * _ctrl.x + e * e * _to.x,
          u * u * _from.y + 2 * u * e * _ctrl.y + e * e * _to.y,
        );
      } else {
        position
          ..setFrom(_from)
          ..lerp(_to, e);
      }
      if (_t >= 1) _fireArrive();
    }
    if (_popT < 1) {
      _popT += dt / 0.3;
      final p = _popT.clamp(0.0, 1.0);
      scale.setAll(1 + 0.25 * math.sin(p * math.pi));
    } else if (scale.x != 1) {
      scale.setAll(1);
    }
    if (_shakeT < 1) _shakeT = math.min(1, _shakeT + dt / 0.3);
  }

  @override
  void render(Canvas canvas) {
    if (_shakeT < 1) {
      canvas.translate(
        math.sin(_shakeT * math.pi * 6) * size.x * 0.08 * (1 - _shakeT),
        0,
      );
    }
    final rect = Offset.zero & Size(size.x, size.y);
    if (item.isHidden) {
      skin.paintHidden(canvas, rect);
    } else {
      skin.paintItem(canvas, rect, item.type, colorblind: colorblind());
    }
    if (item.isFrozen) skin.paintFrozen(canvas, rect);
  }

  static double _easeInOut(double t) =>
      t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
}
