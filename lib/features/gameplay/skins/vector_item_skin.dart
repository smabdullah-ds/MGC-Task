import 'dart:math' as math;
import 'dart:ui';

import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/features/gameplay/skins/item_skin.dart';

/// Placeholder art drawn with vector paths in a warm bazaar palette.
///
/// Each good has its own silhouette *and* colour; colourblind mode adds a
/// white symbol badge on top, so shape alone always identifies an item.
class VectorItemSkin implements ItemSkin {
  /// Creates the skin.
  const new();

  static const List<_Good> _goods = [
    _Good('Saffron jar', Palette.saffron, _jar, _Symbol.circle),
    _Good('Brass lantern', Palette.teal, _lantern, _Symbol.triangle),
    _Good('Clay teacup', Palette.terracotta, _teacup, _Symbol.square),
    _Good('Silk roll', Palette.plum, _fabric, _Symbol.diamond),
    _Good('Olive oil', Palette.olive, _bottle, _Symbol.star),
    _Good('Rose pouch', Palette.rose, _pouch, _Symbol.cross),
    _Good('Rolled rug', Palette.indigo, _rug, _Symbol.bars),
    _Good('Copper pot', Palette.copper, _teapot, _Symbol.ring),
    _Good('Mint tea', Palette.mint, _glass, _Symbol.plus),
    _Good('Pomegranate', Color(0xFFB0233A), _pomegranate, _Symbol.heart),
    _Good('Dates bowl', Color(0xFF7A4A21), _bowl, _Symbol.moon),
    _Good('Brass plate', Color(0xFFD9B44A), _plate, _Symbol.hexagon),
  ];

  @override
  int get typeCount => _goods.length;

  _Good _good(int type) => _goods[type % _goods.length];

  @override
  String nameOf(int type) => _good(type).name;

  @override
  Color colorOf(int type) => _good(type).color;

  @override
  void paintItem(
    Canvas canvas,
    Rect rect,
    int type, {
    required bool colorblind,
  }) {
    final good = _good(type);
    final r = rect.deflate(rect.shortestSide * 0.06);
    // Soft drop shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(r.center.dx, r.bottom - r.height * 0.02),
        width: r.width * 0.8,
        height: r.height * 0.12,
      ),
      Paint()..color = const Color(0x33000000),
    );
    good.draw(canvas, r, good.color);
    if (colorblind) _drawSymbol(canvas, r, good.symbol);
  }

  @override
  void paintHidden(Canvas canvas, Rect rect) {
    final r = rect.deflate(rect.shortestSide * 0.1);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.25));
    canvas
      ..drawRRect(rr, Paint()..color = Palette.woodDark)
      ..drawRRect(
        rr.deflate(r.width * 0.06),
        Paint()..color = const Color(0xFF7D5634),
      );
    final tp = _QuestionMark(r);
    canvas
      ..drawPath(
        tp.path,
        Paint()
          ..color = Palette.sand
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.width * 0.11
          ..strokeCap = StrokeCap.round,
      )
      ..drawCircle(tp.dot, r.width * 0.065, Paint()..color = Palette.sand);
  }

  @override
  void paintFrozen(Canvas canvas, Rect rect) {
    final r = rect.deflate(rect.shortestSide * 0.04);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.2));
    canvas
      ..drawRRect(rr, Paint()..color = const Color(0x8CBFE8FF))
      ..drawRRect(
        rr,
        Paint()
          ..color = const Color(0xFFE8F8FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.width * 0.05,
      );
    final shine = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = r.width * 0.05
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        Offset(r.left + r.width * 0.2, r.top + r.height * 0.35),
        Offset(r.left + r.width * 0.4, r.top + r.height * 0.15),
        shine,
      )
      ..drawLine(
        Offset(r.left + r.width * 0.25, r.top + r.height * 0.55),
        Offset(r.left + r.width * 0.55, r.top + r.height * 0.25),
        shine,
      );
  }
}

typedef _Draw = void Function(Canvas canvas, Rect r, Color c);

class _Good {
  const new(this.name, this.color, this.draw, this.symbol);
  final String name;
  final Color color;
  final _Draw draw;
  final _Symbol symbol;
}

Paint _fill(Color c) => Paint()..color = c;
Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Color _shade(Color c, double f) => Color.from(
  alpha: c.a,
  red: (c.r * f).clamp(0, 1),
  green: (c.g * f).clamp(0, 1),
  blue: (c.b * f).clamp(0, 1),
);

Color _tint(Color c, double f) => Color.from(
  alpha: c.a,
  red: c.r + (1 - c.r) * f,
  green: c.g + (1 - c.g) * f,
  blue: c.b + (1 - c.b) * f,
);

Offset _p(Rect r, double x, double y) =>
    Offset(r.left + r.width * x, r.top + r.height * y);

void _highlight(Canvas canvas, Rect r, double x, double y, double w, double h) {
  canvas.drawOval(
    Rect.fromLTWH(
      r.left + r.width * x,
      r.top + r.height * y,
      r.width * w,
      r.height * h,
    ),
    _fill(const Color(0x55FFFFFF)),
  );
}

void _jar(Canvas canvas, Rect r, Color c) {
  final body = RRect.fromRectAndRadius(
    Rect.fromLTRB(
      r.left + r.width * 0.12,
      r.top + r.height * 0.28,
      r.right - r.width * 0.12,
      r.bottom,
    ),
    Radius.circular(r.width * 0.22),
  );
  canvas
    ..drawRRect(body, _fill(c))
    ..drawRect(
      Rect.fromLTRB(
        r.left + r.width * 0.12,
        r.top + r.height * 0.52,
        r.right - r.width * 0.12,
        r.top + r.height * 0.7,
      ),
      _fill(Palette.ivory),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          r.left + r.width * 0.2,
          r.top + r.height * 0.1,
          r.right - r.width * 0.2,
          r.top + r.height * 0.3,
        ),
        Radius.circular(r.width * 0.06),
      ),
      _fill(Palette.woodDark),
    );
  _highlight(canvas, r, 0.22, 0.34, 0.14, 0.4);
}

void _lantern(Canvas canvas, Rect r, Color c) {
  final dark = _shade(c, 0.6);
  final cap = Path()
    ..moveTo(r.center.dx, r.top)
    ..lineTo(r.right - r.width * 0.18, r.top + r.height * 0.24)
    ..lineTo(r.left + r.width * 0.18, r.top + r.height * 0.24)
    ..close();
  final body = Path()
    ..moveTo(r.left + r.width * 0.2, r.top + r.height * 0.24)
    ..lineTo(r.right - r.width * 0.2, r.top + r.height * 0.24)
    ..lineTo(r.right - r.width * 0.08, r.top + r.height * 0.6)
    ..lineTo(r.right - r.width * 0.24, r.bottom - r.height * 0.08)
    ..lineTo(r.left + r.width * 0.24, r.bottom - r.height * 0.08)
    ..lineTo(r.left + r.width * 0.08, r.top + r.height * 0.6)
    ..close();
  canvas
    ..drawPath(body, _fill(c))
    ..drawPath(cap, _fill(dark))
    ..drawOval(
      Rect.fromCenter(
        center: _p(r, 0.5, 0.57),
        width: r.width * 0.32,
        height: r.height * 0.36,
      ),
      _fill(const Color(0xFFFFE08A)),
    )
    ..drawLine(
      _p(r, 0.5, 0.39),
      _p(r, 0.5, 0.75),
      _stroke(dark, r.width * 0.04),
    )
    ..drawRect(
      Rect.fromLTRB(
        r.left + r.width * 0.28,
        r.bottom - r.height * 0.1,
        r.right - r.width * 0.28,
        r.bottom,
      ),
      _fill(dark),
    );
}

void _teacup(Canvas canvas, Rect r, Color c) {
  final cup = Path()
    ..moveTo(r.left + r.width * 0.08, r.top + r.height * 0.3)
    ..lineTo(r.right - r.width * 0.2, r.top + r.height * 0.3)
    ..quadraticBezierTo(
      r.right - r.width * 0.24,
      r.bottom - r.height * 0.1,
      r.center.dx - r.width * 0.06,
      r.bottom - r.height * 0.14,
    )
    ..quadraticBezierTo(
      r.left + r.width * 0.12,
      r.bottom - r.height * 0.1,
      r.left + r.width * 0.08,
      r.top + r.height * 0.3,
    )
    ..close();
  canvas
    ..drawArc(
      Rect.fromCenter(
        center: _p(r, 0.8, 0.5),
        width: r.width * 0.3,
        height: r.height * 0.3,
      ),
      -math.pi / 2,
      math.pi,
      false,
      _stroke(c, r.width * 0.07),
    )
    ..drawOval(
      Rect.fromCenter(
        center: _p(r, 0.48, 0.92),
        width: r.width * 0.9,
        height: r.height * 0.14,
      ),
      _fill(_shade(c, 0.7)),
    )
    ..drawPath(cup, _fill(c))
    ..drawOval(
      Rect.fromLTRB(
        r.left + r.width * 0.1,
        r.top + r.height * 0.25,
        r.right - r.width * 0.22,
        r.top + r.height * 0.36,
      ),
      _fill(const Color(0xFF6B3A1E)),
    )
    ..drawLine(
      _p(r, 0.22, 0.52),
      _p(r, 0.62, 0.52),
      _stroke(Palette.ivory, r.width * 0.05),
    );
}

void _fabric(Canvas canvas, Rect r, Color c) {
  final body = RRect.fromRectAndRadius(
    Rect.fromLTRB(
      r.left + r.width * 0.06,
      r.top + r.height * 0.18,
      r.right - r.width * 0.06,
      r.bottom - r.height * 0.06,
    ),
    Radius.circular(r.width * 0.1),
  );
  canvas.drawRRect(body, _fill(c));
  final stripe = _stroke(_tint(c, 0.45), r.width * 0.06);
  for (final y in [0.35, 0.55, 0.75]) {
    canvas.drawLine(_p(r, 0.12, y), _p(r, 0.88, y), stripe);
  }
  canvas
    ..drawOval(
      Rect.fromCenter(
        center: _p(r, 0.5, 0.2),
        width: r.width * 0.88,
        height: r.height * 0.16,
      ),
      _fill(_shade(c, 0.75)),
    )
    ..drawOval(
      Rect.fromCenter(
        center: _p(r, 0.5, 0.2),
        width: r.width * 0.3,
        height: r.height * 0.07,
      ),
      _fill(_shade(c, 0.5)),
    );
}

void _bottle(Canvas canvas, Rect r, Color c) {
  final body = Path()
    ..moveTo(r.left + r.width * 0.4, r.top + r.height * 0.06)
    ..lineTo(r.right - r.width * 0.4, r.top + r.height * 0.06)
    ..lineTo(r.right - r.width * 0.4, r.top + r.height * 0.3)
    ..quadraticBezierTo(
      r.right - r.width * 0.14,
      r.top + r.height * 0.38,
      r.right - r.width * 0.16,
      r.bottom - r.height * 0.1,
    )
    ..quadraticBezierTo(
      r.center.dx,
      r.bottom,
      r.left + r.width * 0.16,
      r.bottom - r.height * 0.1,
    )
    ..quadraticBezierTo(
      r.left + r.width * 0.14,
      r.top + r.height * 0.38,
      r.left + r.width * 0.4,
      r.top + r.height * 0.3,
    )
    ..close();
  canvas
    ..drawPath(body, _fill(c))
    ..drawRect(
      Rect.fromLTRB(
        r.left + r.width * 0.37,
        r.top,
        r.right - r.width * 0.37,
        r.top + r.height * 0.1,
      ),
      _fill(Palette.woodDark),
    )
    ..drawOval(
      Rect.fromCenter(
        center: _p(r, 0.5, 0.66),
        width: r.width * 0.42,
        height: r.height * 0.24,
      ),
      _fill(Palette.ivory),
    )
    ..drawCircle(_p(r, 0.5, 0.66), r.width * 0.07, _fill(_shade(c, 0.7)));
  _highlight(canvas, r, 0.26, 0.42, 0.1, 0.3);
}

void _pouch(Canvas canvas, Rect r, Color c) {
  final body = Path()
    ..moveTo(r.left + r.width * 0.34, r.top + r.height * 0.28)
    ..quadraticBezierTo(
      r.left,
      r.top + r.height * 0.6,
      r.left + r.width * 0.16,
      r.bottom - r.height * 0.04,
    )
    ..lineTo(r.right - r.width * 0.16, r.bottom - r.height * 0.04)
    ..quadraticBezierTo(
      r.right,
      r.top + r.height * 0.6,
      r.right - r.width * 0.34,
      r.top + r.height * 0.28,
    )
    ..close();
  final frill = Path()
    ..moveTo(r.left + r.width * 0.3, r.top + r.height * 0.28)
    ..lineTo(r.left + r.width * 0.2, r.top + r.height * 0.06)
    ..lineTo(r.center.dx, r.top + r.height * 0.16)
    ..lineTo(r.right - r.width * 0.2, r.top + r.height * 0.06)
    ..lineTo(r.right - r.width * 0.3, r.top + r.height * 0.28)
    ..close();
  canvas
    ..drawPath(frill, _fill(_shade(c, 0.8)))
    ..drawPath(body, _fill(c))
    ..drawLine(
      _p(r, 0.3, 0.29),
      _p(r, 0.7, 0.29),
      _stroke(Palette.saffronDeep, r.width * 0.07),
    );
  for (final (x, y) in [(0.42, 0.6), (0.6, 0.72), (0.38, 0.8)]) {
    canvas.drawCircle(_p(r, x, y), r.width * 0.05, _fill(_tint(c, 0.5)));
  }
}

void _rug(Canvas canvas, Rect r, Color c) {
  final body = Rect.fromLTRB(
    r.left + r.width * 0.2,
    r.top + r.height * 0.04,
    r.right - r.width * 0.2,
    r.bottom - r.height * 0.06,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(body, Radius.circular(r.width * 0.12)),
    _fill(c),
  );
  final band = _fill(Palette.terracotta);
  for (final y in [0.18, 0.72]) {
    canvas.drawRect(
      Rect.fromLTWH(
        body.left,
        r.top + r.height * y,
        body.width,
        r.height * 0.08,
      ),
      band,
    );
  }
  final diamond = Path()
    ..moveTo(r.center.dx, r.top + r.height * 0.32)
    ..lineTo(r.center.dx + r.width * 0.14, r.top + r.height * 0.48)
    ..lineTo(r.center.dx, r.top + r.height * 0.64)
    ..lineTo(r.center.dx - r.width * 0.14, r.top + r.height * 0.48)
    ..close();
  canvas.drawPath(diamond, _fill(Palette.saffron));
  final fringe = _stroke(Palette.sand, r.width * 0.03);
  for (var i = 0; i < 5; i++) {
    final x = body.left + body.width * (0.15 + i * 0.175);
    canvas.drawLine(Offset(x, body.bottom), Offset(x, r.bottom), fringe);
  }
}

void _teapot(Canvas canvas, Rect r, Color c) {
  final dark = _shade(c, 0.7);
  final spout = Path()
    ..moveTo(r.left + r.width * 0.3, r.top + r.height * 0.6)
    ..quadraticBezierTo(
      r.left + r.width * 0.06,
      r.top + r.height * 0.55,
      r.left,
      r.top + r.height * 0.3,
    )
    ..lineTo(r.left + r.width * 0.1, r.top + r.height * 0.3)
    ..quadraticBezierTo(
      r.left + r.width * 0.16,
      r.top + r.height * 0.48,
      r.left + r.width * 0.34,
      r.top + r.height * 0.48,
    )
    ..close();
  canvas
    ..drawPath(spout, _fill(dark))
    ..drawArc(
      Rect.fromCenter(
        center: _p(r, 0.82, 0.58),
        width: r.width * 0.3,
        height: r.height * 0.36,
      ),
      -math.pi / 2,
      math.pi,
      false,
      _stroke(dark, r.width * 0.06),
    )
    ..drawOval(
      Rect.fromLTRB(
        r.left + r.width * 0.2,
        r.top + r.height * 0.32,
        r.right - r.width * 0.14,
        r.bottom,
      ),
      _fill(c),
    )
    ..drawOval(
      Rect.fromCenter(
        center: _p(r, 0.53, 0.33),
        width: r.width * 0.4,
        height: r.height * 0.12,
      ),
      _fill(dark),
    )
    ..drawCircle(_p(r, 0.53, 0.22), r.width * 0.07, _fill(dark));
  _highlight(canvas, r, 0.32, 0.45, 0.16, 0.22);
}

void _glass(Canvas canvas, Rect r, Color c) {
  final glass = Path()
    ..moveTo(r.left + r.width * 0.2, r.top + r.height * 0.08)
    ..lineTo(r.right - r.width * 0.2, r.top + r.height * 0.08)
    ..quadraticBezierTo(
      r.right - r.width * 0.36,
      r.top + r.height * 0.5,
      r.right - r.width * 0.22,
      r.bottom - r.height * 0.08,
    )
    ..lineTo(r.left + r.width * 0.22, r.bottom - r.height * 0.08)
    ..quadraticBezierTo(
      r.left + r.width * 0.36,
      r.top + r.height * 0.5,
      r.left + r.width * 0.2,
      r.top + r.height * 0.08,
    )
    ..close();
  canvas
    ..drawPath(glass, _fill(const Color(0x66FFFFFF)))
    ..save()
    ..clipPath(glass)
    ..drawRect(
      Rect.fromLTRB(r.left, r.top + r.height * 0.3, r.right, r.bottom),
      _fill(c),
    )
    ..restore()
    ..drawPath(glass, _stroke(_shade(c, 0.6), r.width * 0.04))
    ..drawOval(
      Rect.fromCenter(
        center: _p(r, 0.5, 0.95),
        width: r.width * 0.7,
        height: r.height * 0.1,
      ),
      _fill(Palette.saffronDeep),
    );
  final leaf = Path()
    ..moveTo(r.center.dx, r.top + r.height * 0.32)
    ..quadraticBezierTo(
      r.center.dx + r.width * 0.2,
      r.top,
      r.center.dx + r.width * 0.06,
      r.top - r.height * 0.02,
    )
    ..quadraticBezierTo(
      r.center.dx - r.width * 0.06,
      r.top + r.height * 0.12,
      r.center.dx,
      r.top + r.height * 0.32,
    );
  canvas.drawPath(leaf, _fill(const Color(0xFF2E7D4F)));
}

void _pomegranate(Canvas canvas, Rect r, Color c) {
  final crown = Path()
    ..moveTo(r.center.dx - r.width * 0.14, r.top + r.height * 0.22)
    ..lineTo(r.center.dx - r.width * 0.16, r.top + r.height * 0.04)
    ..lineTo(r.center.dx - r.width * 0.05, r.top + r.height * 0.14)
    ..lineTo(r.center.dx, r.top)
    ..lineTo(r.center.dx + r.width * 0.05, r.top + r.height * 0.14)
    ..lineTo(r.center.dx + r.width * 0.16, r.top + r.height * 0.04)
    ..lineTo(r.center.dx + r.width * 0.14, r.top + r.height * 0.22)
    ..close();
  canvas
    ..drawPath(crown, _fill(_shade(c, 0.7)))
    ..drawCircle(_p(r, 0.5, 0.6), r.width * 0.4, _fill(c));
  _highlight(canvas, r, 0.24, 0.36, 0.2, 0.2);
}

void _bowl(Canvas canvas, Rect r, Color c) {
  final date = _fill(const Color(0xFF4A2511));
  for (final (x, y) in [
    (0.3, 0.42),
    (0.5, 0.36),
    (0.7, 0.42),
    (0.4, 0.3),
    (0.6, 0.3),
  ]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: _p(r, x, y),
        width: r.width * 0.24,
        height: r.height * 0.16,
      ),
      date,
    );
  }
  final bowl = Path()
    ..moveTo(r.left + r.width * 0.04, r.top + r.height * 0.45)
    ..lineTo(r.right - r.width * 0.04, r.top + r.height * 0.45)
    ..quadraticBezierTo(
      r.right - r.width * 0.1,
      r.bottom,
      r.center.dx,
      r.bottom - r.height * 0.04,
    )
    ..quadraticBezierTo(
      r.left + r.width * 0.1,
      r.bottom,
      r.left + r.width * 0.04,
      r.top + r.height * 0.45,
    )
    ..close();
  canvas
    ..drawPath(bowl, _fill(c))
    ..drawLine(
      _p(r, 0.14, 0.62),
      _p(r, 0.86, 0.62),
      _stroke(Palette.saffron, r.width * 0.05),
    );
}

void _plate(Canvas canvas, Rect r, Color c) {
  final center = _p(r, 0.5, 0.55);
  final radius = r.width * 0.44;
  canvas
    ..drawCircle(center, radius, _fill(_shade(c, 0.8)))
    ..drawCircle(center, radius * 0.86, _fill(c));
  final star = Path();
  for (var i = 0; i < 16; i++) {
    final a = -math.pi / 2 + i * math.pi / 8;
    final rad = i.isEven ? radius * 0.62 : radius * 0.32;
    final pt = center + Offset(math.cos(a) * rad, math.sin(a) * rad);
    i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
  }
  star.close();
  canvas
    ..drawPath(star, _fill(_shade(c, 0.65)))
    ..drawCircle(center, radius * 0.14, _fill(Palette.teal));
}

enum _Symbol {
  circle,
  triangle,
  square,
  diamond,
  star,
  cross,
  bars,
  ring,
  plus,
  heart,
  moon,
  hexagon,
}

void _drawSymbol(Canvas canvas, Rect r, _Symbol s) {
  final c = Offset(r.right - r.width * 0.2, r.top + r.height * 0.2);
  final rad = r.width * 0.17;
  canvas
    ..drawCircle(c, rad * 1.25, _fill(Palette.ink))
    ..drawCircle(c, rad * 1.1, _fill(const Color(0xFFFFFFFF)));
  final ink = _fill(Palette.ink);
  final line = _stroke(Palette.ink, rad * 0.32);
  Path poly(int n, double rot, [double scale = 0.8]) {
    final p = Path();
    for (var i = 0; i < n; i++) {
      final a = rot + i * 2 * math.pi / n;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rad * scale;
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  switch (s) {
    case _Symbol.circle:
      canvas.drawCircle(c, rad * 0.55, ink);
    case _Symbol.triangle:
      canvas.drawPath(poly(3, -math.pi / 2), ink);
    case _Symbol.square:
      canvas.drawRect(Rect.fromCenter(center: c, width: rad, height: rad), ink);
    case _Symbol.diamond:
      canvas.drawPath(poly(4, 0), ink);
    case _Symbol.star:
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + i * math.pi / 5;
        final pt =
            c +
            Offset(math.cos(a), math.sin(a)) * rad * (i.isEven ? 0.85 : 0.38);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(p..close(), ink);
    case _Symbol.cross:
      final d = rad * 0.5;
      canvas
        ..drawLine(c + Offset(-d, -d), c + Offset(d, d), line)
        ..drawLine(c + Offset(-d, d), c + Offset(d, -d), line);
    case _Symbol.bars:
      for (final dx in [-0.4, 0.0, 0.4]) {
        canvas.drawLine(
          c + Offset(dx * rad, -rad * 0.55),
          c + Offset(dx * rad, rad * 0.55),
          _stroke(Palette.ink, rad * 0.22),
        );
      }
    case _Symbol.ring:
      canvas.drawCircle(c, rad * 0.5, _stroke(Palette.ink, rad * 0.25));
    case _Symbol.plus:
      canvas
        ..drawLine(c + Offset(-rad * 0.6, 0), c + Offset(rad * 0.6, 0), line)
        ..drawLine(c + Offset(0, -rad * 0.6), c + Offset(0, rad * 0.6), line);
    case _Symbol.heart:
      final p = Path()
        ..moveTo(c.dx, c.dy + rad * 0.6)
        ..cubicTo(
          c.dx - rad * 1.1,
          c.dy - rad * 0.1,
          c.dx - rad * 0.4,
          c.dy - rad * 0.9,
          c.dx,
          c.dy - rad * 0.3,
        )
        ..cubicTo(
          c.dx + rad * 0.4,
          c.dy - rad * 0.9,
          c.dx + rad * 1.1,
          c.dy - rad * 0.1,
          c.dx,
          c.dy + rad * 0.6,
        )
        ..close();
      canvas.drawPath(p, ink);
    case _Symbol.moon:
      canvas
        ..drawCircle(c, rad * 0.62, ink)
        ..drawCircle(
          c + Offset(rad * 0.3, -rad * 0.15),
          rad * 0.5,
          _fill(const Color(0xFFFFFFFF)),
        );
    case _Symbol.hexagon:
      canvas.drawPath(poly(6, 0), ink);
  }
}

class _QuestionMark {
  new(Rect r)
    : path = Path()
        ..moveTo(r.left + r.width * 0.34, r.top + r.height * 0.36)
        ..quadraticBezierTo(
          r.left + r.width * 0.36,
          r.top + r.height * 0.16,
          r.center.dx,
          r.top + r.height * 0.18,
        )
        ..quadraticBezierTo(
          r.right - r.width * 0.3,
          r.top + r.height * 0.2,
          r.right - r.width * 0.34,
          r.top + r.height * 0.4,
        )
        ..quadraticBezierTo(
          r.right - r.width * 0.38,
          r.top + r.height * 0.5,
          r.center.dx,
          r.top + r.height * 0.56,
        )
        ..lineTo(r.center.dx, r.top + r.height * 0.64),
      dot = Offset(r.center.dx, r.top + r.height * 0.8);

  final Path path;
  final Offset dot;
}
