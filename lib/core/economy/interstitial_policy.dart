import 'package:bazaar_sort/core/level_gen/seeded_random.dart';

/// Interstitial pacing knobs (all from Remote Config).
final class InterstitialConfig {
  /// Creates a config; defaults are the launch values.
  const new({
    this.enabled = true,
    this.minLevel = 10,
    this.levelGapMin = 2,
    this.levelGapMax = 3,
    this.cooldown = const Duration(seconds: 90),
    this.afterRewarded = const Duration(minutes: 3),
  });

  /// Master switch.
  final bool enabled;

  /// No interstitials before this level (tutorial).
  final int minLevel;

  /// Fewest completed levels between interstitials.
  final int levelGapMin;

  /// Most completed levels between interstitials.
  final int levelGapMax;

  /// Minimum time between interstitials.
  final Duration cooldown;

  /// Quiet period after a rewarded ad.
  final Duration afterRewarded;
}

/// Why an interstitial was (not) shown. Logged for tuning.
enum InterstitialDecision {
  show,
  disabled,
  adFree,
  tutorial,
  hadFailure,
  levelGap,
  cooldown,
  afterRewarded,
}

/// Decides when an interstitial may show. Only ever consulted *after a level
/// is completed* — never mid-level, never on a fail screen.
///
/// Rules: from level 10; every 2–3 completed levels (randomised per gap);
/// at least 90 s apart; not for 3 minutes after a rewarded ad; never after a
/// level the player failed or restarted before winning; never for ad-free
/// players.
final class InterstitialPolicy {
  /// Creates a policy.
  new({this.config = const InterstitialConfig(), SeededRandom? random})
    : _random = random ?? SeededRandom(DateTime.now().millisecond) {
    _nextGap = _pickGap();
  }

  /// Pacing knobs.
  final InterstitialConfig config;

  final SeededRandom _random;
  int _levelsSinceLast = 0;
  late int _nextGap;
  DateTime? _lastShown;

  int _pickGap() {
    final span = config.levelGapMax - config.levelGapMin + 1;
    return config.levelGapMin + (span > 0 ? _random.nextInt(span) : 0);
  }

  /// Completed levels since the last interstitial.
  int get levelsSinceLast => _levelsSinceLast;

  /// Records a completed level. Call before [decide].
  void recordLevelComplete() => _levelsSinceLast++;

  /// When a rewarded ad was last watched (interstitials pause after it).
  DateTime? lastRewardedAt;

  /// Records an interstitial impression.
  void recordShown(DateTime now) {
    _lastShown = now;
    _levelsSinceLast = 0;
    _nextGap = _pickGap();
  }

  /// Whether to show an interstitial after completing [level].
  InterstitialDecision decide({
    required int level,
    required DateTime now,
    required bool adFree,
    required bool hadFailure,
  }) {
    if (!config.enabled) return InterstitialDecision.disabled;
    if (adFree) return InterstitialDecision.adFree;
    if (level < config.minLevel) return InterstitialDecision.tutorial;
    if (hadFailure) return InterstitialDecision.hadFailure;
    if (_levelsSinceLast < _nextGap) return InterstitialDecision.levelGap;
    final shown = _lastShown;
    if (shown != null && now.difference(shown) < config.cooldown) {
      return InterstitialDecision.cooldown;
    }
    final rewarded = lastRewardedAt;
    if (rewarded != null && now.difference(rewarded) < config.afterRewarded) {
      return InterstitialDecision.afterRewarded;
    }
    return InterstitialDecision.show;
  }
}
