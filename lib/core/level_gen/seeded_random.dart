/// Small, fast PRNG (mulberry32) with a stable algorithm.
///
/// `dart:math`'s `Random` makes no promise that a seed produces the same
/// sequence across SDK versions or platforms. Levels must be identical on
/// every device forever, so the generator uses this instead.
final class SeededRandom {
  /// Creates a generator from a 32-bit [seed].
  new(int seed) : _state = seed & _mask32;

  static const int _mask32 = 0xFFFFFFFF;

  int _state;

  /// Next unsigned 32-bit value.
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & _mask32;
    var t = _state;
    t = _imul(t ^ (t >> 15), t | 1);
    t ^= (t + _imul(t ^ (t >> 7), t | 61)) & _mask32;
    return (t ^ (t >> 14)) & _mask32;
  }

  /// Uniform integer in `[0, max)`. [max] must be positive.
  int nextInt(int max) {
    assert(max > 0, 'max must be positive');
    return nextUint32() % max;
  }

  /// Uniform double in `[0, 1)`.
  double nextDouble() => nextUint32() / 4294967296.0;

  /// `true` with probability [p].
  bool chance(double p) => nextDouble() < p;

  /// A random element of [items].
  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// Fisher–Yates shuffle in place.
  void shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }

  /// Derives an independent seed for a sub-stream (e.g. attempt N).
  static int derive(int seed, int salt) {
    var h = (seed ^ (salt * 0x9E3779B1)) & _mask32;
    h = _imul(h ^ (h >> 16), 0x85EBCA6B);
    h = _imul(h ^ (h >> 13), 0xC2B2AE35);
    return (h ^ (h >> 16)) & _mask32;
  }

  /// 32-bit multiply with wrap-around, like JavaScript's `Math.imul`.
  static int _imul(int a, int b) {
    final aHi = (a >> 16) & 0xFFFF;
    final aLo = a & 0xFFFF;
    final bHi = (b >> 16) & 0xFFFF;
    final bLo = b & 0xFFFF;
    return (aLo * bLo + (((aHi * bLo + aLo * bHi) << 16) & _mask32)) & _mask32;
  }
}
