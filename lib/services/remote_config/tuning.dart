import 'package:bazaar_sort/config/remote_config_defaults.dart';
import 'package:bazaar_sort/core/economy/economy_config.dart';
import 'package:bazaar_sort/core/level_gen/difficulty_curve.dart';
import 'package:bazaar_sort/services/remote_config/remote_config_service.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds [EconomyConfig] from Remote Config (falls back to local defaults).
EconomyConfig economyFrom(RemoteConfigService rc) => EconomyConfig(
  coinsBase: rc.getInt(RcKeys.coinsBase),
  coinsPerStar: rc.getInt(RcKeys.coinsPerStar),
  coinsBossBonus: rc.getInt(RcKeys.coinsBossBonus),
  freeUndosPerLevel: rc.getInt(RcKeys.freeUndosPerLevel),
  undosPerAd: rc.getInt(RcKeys.undosPerAd),
  priceExtraShelf: rc.getInt(RcKeys.priceExtraShelf),
  priceHint: rc.getInt(RcKeys.priceHint),
  priceShuffle: rc.getInt(RcKeys.priceShuffle),
  priceUndoPack: rc.getInt(RcKeys.priceUndoPack),
  priceExtraMoves: rc.getInt(RcKeys.priceExtraMoves),
  extraMovesAmount: rc.getInt(RcKeys.extraMovesAmount),
  bazaarCostMultiplier: rc.getDouble(RcKeys.bazaarCostMultiplier),
  dailyChallengeReward: rc.getInt(RcKeys.dailyChallengeReward),
  threeStarRatio: rc.getDouble(RcKeys.starThreeRatio),
  twoStarRatio: rc.getDouble(RcKeys.starTwoRatio),
  vipDailyCoins: rc.getInt(RcKeys.vipDailyCoins),
  starterPackMinLevel: rc.getInt(RcKeys.starterPackMinLevel),
  starterPackHours: rc.getInt(RcKeys.starterPackHours),
);

/// Live economy values.
final economyConfigProvider = Provider<EconomyConfig>(
  (ref) => economyFrom(ref.watch(remoteConfigServiceProvider)),
);

/// Live difficulty curve (used for levels generated on device).
final difficultyCurveProvider = Provider<DifficultyCurve>(
  (ref) => DifficultyCurve(
    DifficultyCurveConfig.fromJson(
      ref
          .watch(remoteConfigServiceProvider)
          .getString(RcKeys.difficultyCurveJson),
    ),
  ),
);
