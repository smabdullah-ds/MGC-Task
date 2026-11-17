import 'dart:math' as math;
import 'dart:ui';

import 'package:bazaar_sort/app/palette.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';

const List<Color> _confettiColors = [
  Palette.saffron,
  Palette.teal,
  Palette.terracotta,
  Palette.rose,
  Palette.mint,
  Palette.plum,
];

/// Win celebration: paper confetti falling from the top of the screen.
class Confetti extends ParticleSystemComponent {
  /// Creates confetti over [area].
  new({required Vector2 area, int count = 90, int seed = 1})
    : super(particle: _build(area, count, math.Random(seed)), priority: 100);

  static Particle _build(Vector2 area, int count, math.Random rnd) {
    return Particle.generate(
      count: count,
      lifespan: 2.6,
      generator: (i) {
        final color = _confettiColors[i % _confettiColors.length];
        final w = 6 + rnd.nextDouble() * 6;
        final spin = (rnd.nextDouble() - 0.5) * 12;
        return AcceleratedParticle(
          position: Vector2(
            rnd.nextDouble() * area.x,
            -20 - rnd.nextDouble() * 80,
          ),
          speed: Vector2(
            (rnd.nextDouble() - 0.5) * 160,
            120 + rnd.nextDouble() * 160,
          ),
          acceleration: Vector2(0, 180),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final p = particle.progress;
              canvas
                ..save()
                ..rotate(spin * p)
                ..drawRect(
                  Rect.fromCenter(
                    center: Offset.zero,
                    width: w,
                    height: w * 0.5 * (0.4 + 0.6 * math.cos(p * 20).abs()),
                  ),
                  Paint()..color = color.withValues(alpha: 1 - p * p),
                )
                ..restore();
            },
          ),
        );
      },
    );
  }
}

/// Small burst of sparkles when a shelf completes.
class SparkleBurst extends ParticleSystemComponent {
  /// Creates a burst at [center] tinted [color].
  new({required Vector2 center, required Color color})
    : super(
        particle: Particle.generate(
          count: 18,
          lifespan: 0.7,
          generator: (i) {
            final a = i / 18 * math.pi * 2;
            final speed = 90 + (i * 37 % 60).toDouble();
            return AcceleratedParticle(
              position: center.clone(),
              speed: Vector2(math.cos(a), math.sin(a)) * speed,
              acceleration: Vector2(0, 160),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final r = 4 * (1 - particle.progress);
                  canvas
                    ..drawCircle(
                      Offset.zero,
                      r + 2,
                      Paint()..color = const Color(0x88FFF3C4),
                    )
                    ..drawCircle(
                      Offset.zero,
                      r,
                      Paint()..color = i.isEven ? color : Palette.saffron,
                    );
                },
              ),
            );
          },
        ),
        priority: 50,
      );
}
