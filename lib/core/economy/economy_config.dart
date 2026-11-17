import 'package:bazaar_sort/core/economy/booster.dart';

/// Tunable economy values. Built from Remote Config in the app layer; the
/// defaults match `remote_config_defaults.dart`.
final class EconomyConfig {
  /// Creates a config.
  const new({
    this.coinsBase = 20,
    this.coinsPerStar = 10,
    this.coinsBossBonus = 50,
    this.freeUndosPerLevel = 3,
    this.undosPerAd = 3,
    this.priceExtraShelf = 120,
    this.priceHint = 60,
    this.priceShuffle = 80,
    this.priceUndoPack = 50,
    this.priceExtraMoves = 100,
    this.extraMovesAmount = 5,
    this.bazaarCostMultiplier = 1.0,
    this.dailyChallengeReward = 100,
    this.threeStarRatio = 1.2,
    this.twoStarRatio = 1.6,
    this.vipDailyCoins = 200,
    this.starterPackMinLevel = 15,
    this.starterPackHours = 48,
  });

  /// Coins for any completed level.
  final int coinsBase;

  /// Extra coins per star.
  final int coinsPerStar;

  /// Extra coins on boss levels.
  final int coinsBossBonus;

  /// Free undos at the start of each level.
  final int freeUndosPerLevel;

  /// Undos granted by one rewarded ad.
  final int undosPerAd;

  /// Coin price of the extra shelf.
  final int priceExtraShelf;

  /// Coin price of a hint.
  final int priceHint;

  /// Coin price of a shuffle.
  final int priceShuffle;

  /// Coin price of an undo refill.
  final int priceUndoPack;

  /// Coin price of extra moves on a move-limited fail.
  final int priceExtraMoves;

  /// Moves added by "extra moves".
  final int extraMovesAmount;

  /// Multiplier on bazaar restoration costs.
  final double bazaarCostMultiplier;

  /// Coins for finishing the daily challenge.
  final int dailyChallengeReward;

  /// 3★ threshold multiplier on optimal moves.
  final double threeStarRatio;

  /// 2★ threshold multiplier on optimal moves.
  final double twoStarRatio;

  /// VIP daily coin grant.
  final int vipDailyCoins;

  /// Starter pack is offered after this level.
  final int starterPackMinLevel;

  /// Starter pack offer window.
  final int starterPackHours;

  /// Coin price of [type] (the undo price buys a refill).
  int priceOf(BoosterType type) => switch (type) {
    BoosterType.undo => priceUndoPack,
    BoosterType.extraShelf => priceExtraShelf,
    BoosterType.hint => priceHint,
    BoosterType.shuffle => priceShuffle,
  };

  /// Coins for finishing a level with [stars]; boss levels add a bonus.
  int levelCoins({required int stars, required bool boss}) =>
      coinsBase + coinsPerStar * stars + (boss ? coinsBossBonus : 0);
}
