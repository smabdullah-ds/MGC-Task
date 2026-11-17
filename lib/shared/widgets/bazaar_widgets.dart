import 'dart:math' as math;

import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/config/constants.dart';
import 'package:material_ui/material_ui.dart';

/// A gold coin icon drawn with a painter (no image assets needed).
class CoinIcon extends StatelessWidget {
  const new({this.size = 22, super.key});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CoinPainter());
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas
      ..drawCircle(c, r, Paint()..color = Palette.saffronDeep)
      ..drawCircle(c, r * 0.82, Paint()..color = Palette.saffron)
      ..drawCircle(
        c,
        r * 0.5,
        Paint()
          ..color = Palette.saffronDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.14,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Coin balance chip. Tapping opens the shop when [onTap] is set.
class CoinPill extends StatelessWidget {
  const new({required this.coins, this.onTap, super.key});

  final int coins;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = coins.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return Semantics(
      label: '$coins coins',
      button: onTap != null,
      child: Material(
        color: Palette.woodDark,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppConstants.minTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 14, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinIcon(),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Palette.ivory,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.add_circle,
                      color: Palette.saffron,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 1–3 stars, filled up to [stars].
class StarRow extends StatelessWidget {
  const new({required this.stars, this.size = 40, super.key});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$stars of 3 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == 1 ? size * 0.3 : 0),
              child: Icon(
                i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: i == 1 ? size * 1.25 : size,
                color: i < stars ? Palette.saffron : Palette.sand,
              ),
            ),
        ],
      ),
    );
  }
}

/// Small "AD" tag shown on anything that plays a rewarded video, so ads are
/// always clearly labelled.
class AdBadge extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: Palette.teal,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_arrow_rounded, size: 12, color: Palette.ivory),
        Text(
          'AD',
          style: TextStyle(
            color: Palette.ivory,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

/// Warm patterned backdrop used behind every screen.
class BazaarBackground extends StatelessWidget {
  const new({required this.child, this.dark = false, super.key});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // Own layer: the pattern is painted once, not every animation frame.
      RepaintBoundary(
        child: CustomPaint(painter: _PatternPainter(dark: dark)),
      ),
      child,
    ],
  );
}

class _PatternPainter extends CustomPainter {
  new({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF2B1B10), Color(0xFF4A2C14)]
              : const [Color(0xFFFFF1D6), Color(0xFFF6D9A8)],
        ).createShader(rect),
    );
    // Faint eight-point star tiles, a classic bazaar motif.
    final motif = Paint()
      ..color = (dark ? Palette.saffron : Palette.wood).withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const step = 64.0;
    for (var y = 0.0; y < size.height + step; y += step) {
      for (
        var x = ((y / step).floor().isEven ? 0.0 : step / 2);
        x < size.width + step;
        x += step
      ) {
        final c = Offset(x, y);
        for (final rot in [0.0, math.pi / 4]) {
          final p = Path();
          for (var i = 0; i < 4; i++) {
            final a = rot + i * math.pi / 2;
            final pt = c + Offset(math.cos(a), math.sin(a)) * 16;
            i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
          }
          canvas.drawPath(p..close(), motif);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) => old.dark != dark;
}
