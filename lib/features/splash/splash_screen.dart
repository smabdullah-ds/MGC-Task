import 'dart:async';

import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/app/routes.dart';
import 'package:bazaar_sort/app/startup.dart';
import 'package:bazaar_sort/shared/utils/l10n.dart';
import 'package:bazaar_sort/shared/widgets/bazaar_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Shows the logo while consent runs, then opens the home screen.
class SplashScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_go());
  }

  Future<void> _go() async {
    await Future.wait<void>([
      ref.read(startupProvider.future).then((_) {}, onError: (Object _) {}),
      Future<void>.delayed(const Duration(milliseconds: 600)),
    ]);
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BazaarBackground(
        dark: true,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BazaarLogo(size: 140),
              const SizedBox(height: 24),
              Text(
                context.l10n.appTitle,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Palette.saffron,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(color: Palette.saffron),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.loading,
                style: const TextStyle(color: Palette.sand),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The game mark: an arched bazaar doorway with stacked goods.
class BazaarLogo extends StatelessWidget {
  const new({this.size = 120, super.key});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final arch = Path()
      ..moveTo(w * 0.1, s.height)
      ..lineTo(w * 0.1, s.height * 0.45)
      ..quadraticBezierTo(w * 0.1, 0, w * 0.5, 0)
      ..quadraticBezierTo(w * 0.9, 0, w * 0.9, s.height * 0.45)
      ..lineTo(w * 0.9, s.height)
      ..close();
    canvas
      ..drawPath(arch, Paint()..color = Palette.teal)
      ..drawPath(
        arch,
        Paint()
          ..color = Palette.saffron
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.05,
      );
    const colors = [Palette.saffron, Palette.terracotta, Palette.ivory];
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            w * 0.3,
            s.height * (0.78 - i * 0.18),
            w * 0.4,
            s.height * 0.15,
          ),
          Radius.circular(w * 0.05),
        ),
        Paint()..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
