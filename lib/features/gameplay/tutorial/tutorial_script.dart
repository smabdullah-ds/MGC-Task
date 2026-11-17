/// One coach message shown during a level.
final class TutorialStep {
  /// Creates a step.
  const new(this.id, {this.guideMoves = false, this.highlight});

  /// Stable id (analytics `tutorial_step`, l10n key `tut_<id>`).
  final String id;

  /// Whether a pointing hand walks the player through solver moves.
  final bool guideMoves;

  /// HUD element to highlight, e.g. `undo`.
  final String? highlight;
}

/// Which coach messages appear on which levels. Levels 1–10 teach the
/// basics; obstacle levels introduce each obstacle once.
abstract final class TutorialScript {
  static const Map<int, TutorialStep> _byLevel = {
    1: TutorialStep('pick', guideMoves: true),
    2: TutorialStep('match', guideMoves: true),
    3: TutorialStep('empty'),
    4: TutorialStep('undo', highlight: 'undo'),
    5: TutorialStep('stars'),
    6: TutorialStep('hint', highlight: 'hint'),
    7: TutorialStep('partial'),
    8: TutorialStep('extra_shelf', highlight: 'extra_shelf'),
    9: TutorialStep('shuffle', highlight: 'shuffle'),
    10: TutorialStep('boss'),
    20: TutorialStep('hidden'),
    40: TutorialStep('locked'),
    60: TutorialStep('frozen'),
    80: TutorialStep('move_limit'),
  };

  /// Step for [level], if any.
  static TutorialStep? forLevel(int level) => _byLevel[level];

  /// Whether [level] belongs to the tutorial (no interstitials, no fails
  /// counted against the player).
  static bool isTutorial(int level) => level <= 10;
}
