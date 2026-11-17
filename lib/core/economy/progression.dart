import 'dart:math' as math;

import 'package:bazaar_sort/core/economy/booster.dart';
import 'package:bazaar_sort/core/economy/economy_config.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';

/// Result of finishing a level.
final class LevelCompletion {
  /// Creates a result.
  const new(this.state, this.coins, {required this.firstClear});

  /// New player state (already includes [coins]).
  final PlayerState state;

  /// Coins granted.
  final int coins;

  /// Whether this was the first time the level was beaten.
  final bool firstClear;
}

/// Pure state transitions for progress, coins and boosters. Every method
/// returns a new [PlayerState]; spending returns `null` when unaffordable.
final class Progression {
  /// Creates progression rules with [config].
  const new([this.config = const EconomyConfig()]);

  /// Economy values.
  final EconomyConfig config;

  /// Records a win of [level] with [stars] and grants its coins in the same
  /// state change, so one save makes the win durable (the app may be killed
  /// on the win screen).
  ///
  /// Replays of already-beaten levels grant only the base coins.
  LevelCompletion completeLevel(
    PlayerState state, {
    required int level,
    required int stars,
    required bool boss,
  }) {
    final firstClear = level >= state.nextLevel;
    final coins = firstClear
        ? config.levelCoins(stars: stars, boss: boss)
        : config.coinsBase;
    final best = math.max(state.stars[level] ?? 0, stars);
    final next = state.copyWith(
      nextLevel: firstClear ? level + 1 : state.nextLevel,
      stars: {...state.stars, level: best},
      coins: state.coins + coins,
      levelsCompleted: state.levelsCompleted + 1,
      lastWin: LastWin(level: level, coins: coins),
    );
    return LevelCompletion(next, coins, firstClear: firstClear);
  }

  /// Grants the "2× coins" bonus for the last win once. `null` if there is
  /// no win to double or it was already doubled.
  PlayerState? doubleLastWin(PlayerState state) {
    final win = state.lastWin;
    if (win == null || win.doubled) return null;
    return state.copyWith(
      coins: state.coins + win.coins,
      lastWin: LastWin(level: win.level, coins: win.coins, doubled: true),
    );
  }

  /// Adds [amount] coins.
  PlayerState earn(PlayerState state, int amount) {
    assert(amount >= 0, 'use spend() to remove coins');
    return state.copyWith(coins: state.coins + amount);
  }

  /// Removes [amount] coins, or `null` if the balance is too low.
  PlayerState? spend(PlayerState state, int amount) {
    assert(amount >= 0, 'amount must be positive');
    if (state.coins < amount) return null;
    return state.copyWith(coins: state.coins - amount);
  }

  /// Adds [count] owned charges of [type].
  PlayerState addBooster(PlayerState state, BoosterType type, int count) =>
      state.copyWith(
        boosters: {...state.boosters, type: state.boosterCount(type) + count},
      );

  /// Consumes one owned charge of [type], or `null` if none are owned.
  PlayerState? useBooster(PlayerState state, BoosterType type) {
    final n = state.boosterCount(type);
    if (n <= 0) return null;
    return state.copyWith(boosters: {...state.boosters, type: n - 1});
  }

  /// Buys one use of [type] for coins, or `null` if unaffordable.
  PlayerState? buyBooster(PlayerState state, BoosterType type) =>
      spend(state, config.priceOf(type));
}
