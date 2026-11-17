/// Converts a move count into 1–3 stars relative to the solver's optimum.
final class StarRating {
  /// Creates a rating policy. Defaults: 3★ at ≤ optimal × 1.2,
  /// 2★ at ≤ optimal × 1.6, otherwise 1★.
  const new({this.threeStarRatio = 1.2, this.twoStarRatio = 1.6})
    : assert(
        threeStarRatio <= twoStarRatio,
        'three-star ratio must not exceed two-star ratio',
      );

  /// Multiplier on optimal moves for three stars.
  final double threeStarRatio;

  /// Multiplier on optimal moves for two stars.
  final double twoStarRatio;

  /// Stars for finishing in [moves] when the optimum is [optimalMoves].
  int stars({required int moves, required int optimalMoves}) {
    if (optimalMoves <= 0) return 3;
    // Small epsilon so 12 moves at optimal 10 × 1.2 counts as "at or under".
    if (moves <= optimalMoves * threeStarRatio + 1e-9) return 3;
    if (moves <= optimalMoves * twoStarRatio + 1e-9) return 2;
    return 1;
  }

  /// Largest move count that still earns [stars] stars.
  int movesFor(int stars, int optimalMoves) => switch (stars) {
    3 => (optimalMoves * threeStarRatio + 1e-9).floor(),
    2 => (optimalMoves * twoStarRatio + 1e-9).floor(),
    _ => 1 << 30,
  };
}
