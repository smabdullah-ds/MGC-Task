/// Remote Config keys and their local defaults.
///
/// Every tuning value in the game is read through `RemoteConfigService`
/// using one of these keys. The defaults below are what ships in the binary
/// and what the game uses offline or before the first fetch completes.
/// Keep this file and the Firebase console template in sync
/// (see KPI.md → "Remote Config template").
abstract final class RcKeys {
  // ---- Interstitial pacing -----------------------------------------------
  static const String interstitialsEnabled = 'ads_interstitials_enabled';
  static const String interstitialMinLevel = 'ads_interstitial_min_level';
  static const String interstitialLevelGapMin =
      'ads_interstitial_level_gap_min';
  static const String interstitialLevelGapMax =
      'ads_interstitial_level_gap_max';
  static const String interstitialCooldownSeconds =
      'ads_interstitial_cooldown_s';
  static const String interstitialPostRewardedSeconds =
      'ads_interstitial_post_rewarded_s';

  // ---- Other ad formats ----------------------------------------------------
  static const String bannerBazaarEnabled = 'ads_banner_bazaar_enabled';
  static const String appOpenEnabled = 'ads_app_open_enabled';
  static const String freeUndosPerLevel = 'boost_free_undos_per_level';
  static const String undosPerAd = 'boost_undos_per_ad';

  // ---- Economy -------------------------------------------------------------
  static const String coinsBase = 'eco_coins_base';
  static const String coinsPerStar = 'eco_coins_per_star';
  static const String coinsBossBonus = 'eco_coins_boss_bonus';
  static const String priceExtraShelf = 'eco_price_extra_shelf';
  static const String priceHint = 'eco_price_hint';
  static const String priceShuffle = 'eco_price_shuffle';
  static const String priceUndoPack = 'eco_price_undo_pack';
  static const String priceExtraMoves = 'eco_price_extra_moves';
  static const String extraMovesAmount = 'eco_extra_moves_amount';
  static const String bazaarCostMultiplier = 'eco_bazaar_cost_multiplier';
  static const String dailyChallengeReward = 'eco_daily_challenge_reward';
  static const String starThreeRatio = 'eco_star3_ratio';
  static const String starTwoRatio = 'eco_star2_ratio';
  static const String vipDailyCoins = 'eco_vip_daily_coins';

  // ---- IAP offers ------------------------------------------------------------
  static const String starterPackMinLevel = 'iap_starter_min_level';
  static const String starterPackHours = 'iap_starter_hours';

  // ---- Difficulty curve ------------------------------------------------------
  /// JSON object overriding any field of `DifficultyCurveConfig`.
  /// Empty string = use the built-in curve.
  static const String difficultyCurveJson = 'difficulty_curve_json';

  // ---- Notifications --------------------------------------------------------
  static const String notificationsEnabled = 'push_local_enabled';
  static const String quietHoursStart = 'push_quiet_start_hour';
  static const String quietHoursEnd = 'push_quiet_end_hour';

  // ---- Experiments -----------------------------------------------------------
  /// Free-form experiment label stamped on analytics as a user property.
  static const String experimentGroup = 'exp_group';
}

/// Local defaults for every key in [RcKeys].
const Map<String, Object> remoteConfigDefaults = <String, Object>{
  RcKeys.interstitialsEnabled: true,
  RcKeys.interstitialMinLevel: 10,
  RcKeys.interstitialLevelGapMin: 2,
  RcKeys.interstitialLevelGapMax: 3,
  RcKeys.interstitialCooldownSeconds: 90,
  RcKeys.interstitialPostRewardedSeconds: 180,
  RcKeys.bannerBazaarEnabled: false,
  RcKeys.appOpenEnabled: false,
  RcKeys.freeUndosPerLevel: 3,
  RcKeys.undosPerAd: 3,
  RcKeys.coinsBase: 20,
  RcKeys.coinsPerStar: 10,
  RcKeys.coinsBossBonus: 50,
  RcKeys.priceExtraShelf: 120,
  RcKeys.priceHint: 60,
  RcKeys.priceShuffle: 80,
  RcKeys.priceUndoPack: 50,
  RcKeys.priceExtraMoves: 100,
  RcKeys.extraMovesAmount: 5,
  RcKeys.bazaarCostMultiplier: 1.0,
  RcKeys.dailyChallengeReward: 100,
  RcKeys.starThreeRatio: 1.2,
  RcKeys.starTwoRatio: 1.6,
  RcKeys.vipDailyCoins: 200,
  RcKeys.starterPackMinLevel: 15,
  RcKeys.starterPackHours: 48,
  RcKeys.difficultyCurveJson: '',
  RcKeys.notificationsEnabled: true,
  RcKeys.quietHoursStart: 22,
  RcKeys.quietHoursEnd: 9,
  RcKeys.experimentGroup: 'control',
};
