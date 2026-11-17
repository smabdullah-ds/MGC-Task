/// The four boosters.
enum BoosterType {
  /// Revert the last move.
  undo,

  /// Add one empty shelf (once per level).
  extraShelf,

  /// Highlight the solver's next move.
  hint,

  /// Re-deal movable goods, keeping the level solvable.
  shuffle,
}

/// How a booster was paid for (analytics `source`).
enum BoosterSource { free, coins, ad, inventory }
