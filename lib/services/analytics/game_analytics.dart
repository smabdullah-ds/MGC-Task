import 'dart:async';

import 'package:bazaar_sort/services/analytics/analytics_service.dart';

/// Event names. Firebase limits: ≤ 40 chars, snake_case.
abstract final class Ev {
  static const levelStart = 'level_start';
  static const levelComplete = 'level_complete';
  static const levelFail = 'level_fail';
  static const levelRestart = 'level_restart';
  static const boosterUsed = 'booster_used';
  static const adRequest = 'ad_request';
  static const adLoaded = 'ad_loaded';
  static const adImpression = 'ad_impression';
  static const adRewardGranted = 'ad_reward_granted';
  static const adFailed = 'ad_failed';
  static const iapView = 'iap_view';
  static const iapPurchase = 'iap_purchase';
  static const iapFailed = 'iap_failed';
  static const coinsEarned = 'coins_earned';
  static const coinsSpent = 'coins_spent';
  static const bazaarItemRestored = 'bazaar_item_restored';
  static const areaComplete = 'area_complete';
  static const dailyRewardClaimed = 'daily_reward_claimed';
  static const dailyChallengeComplete = 'daily_challenge_complete';
  static const tutorialStep = 'tutorial_step';
  static const consentResult = 'consent_result';
  static const settingsChanged = 'settings_changed';
}

/// User property names.
abstract final class UserProp {
  static const countryTier = 'install_country_tier';
  static const payer = 'payer';
  static const adFree = 'ad_free';
  static const experiment = 'exp_group';
}

/// Typed wrapper so every call site uses the same parameter names.
class GameAnalytics {
  /// Creates the wrapper.
  const new(this._a);

  final AnalyticsService _a;

  void _log(String name, Map<String, Object> p) =>
      unawaited(_a.logEvent(name, p));

  /// A level attempt started.
  void levelStart({
    required int level,
    required String kind,
    int attempt = 1,
  }) => _log(Ev.levelStart, {'level': level, 'kind': kind, 'attempt': attempt});

  /// A level was won.
  void levelComplete({
    required int level,
    required int moves,
    required int optimalMoves,
    required int stars,
    required int durationS,
    required int boostersUsed,
  }) => _log(Ev.levelComplete, {
    'level': level,
    'moves': moves,
    'optimal_moves': optimalMoves,
    'stars': stars,
    'duration_s': durationS,
    'boosters_used': boostersUsed,
  });

  /// A level was failed (stuck, out of moves, quit).
  void levelFail({
    required int level,
    required String reason,
    required int moves,
    required int durationS,
  }) => _log(Ev.levelFail, {
    'level': level,
    'reason': reason,
    'moves': moves,
    'duration_s': durationS,
  });

  /// The player restarted.
  void levelRestart({required int level, required int moves}) =>
      _log(Ev.levelRestart, {'level': level, 'moves': moves});

  /// A booster was used. [source] is `coins`, `ad`, `free` or `inventory`.
  void boosterUsed({
    required String type,
    required String source,
    required int level,
  }) => _log(Ev.boosterUsed, {'type': type, 'source': source, 'level': level});

  /// Coins entered the economy.
  void coinsEarned({required int amount, required String source}) =>
      _log(Ev.coinsEarned, {'amount': amount, 'source': source});

  /// Coins left the economy.
  void coinsSpent({required int amount, required String sink}) =>
      _log(Ev.coinsSpent, {'amount': amount, 'sink': sink});

  /// A tutorial step was shown.
  void tutorialStep({required String step, required int level}) =>
      _log(Ev.tutorialStep, {'step': step, 'level': level});

  /// A setting changed.
  void settingsChanged({required String setting, required String value}) =>
      _log(Ev.settingsChanged, {'setting': setting, 'value': value});

  /// A bazaar item was restored.
  void bazaarItemRestored({
    required String item,
    required String area,
    required int cost,
  }) => _log(Ev.bazaarItemRestored, {'item': item, 'area': area, 'cost': cost});

  /// A bazaar area was completed.
  void areaComplete({required String area, required int levelsPlayed}) =>
      _log(Ev.areaComplete, {'area': area, 'levels_played': levelsPlayed});

  /// The daily login reward was claimed.
  void dailyRewardClaimed({required int day, required int coins}) =>
      _log(Ev.dailyRewardClaimed, {'day': day, 'coins': coins});

  /// The daily challenge was won.
  void dailyChallengeComplete({required int streak, required int moves}) =>
      _log(Ev.dailyChallengeComplete, {'streak': streak, 'moves': moves});

  /// The shop (or an offer) was opened.
  void iapView({required String placement}) =>
      _log(Ev.iapView, {'placement': placement});

  /// A purchase succeeded.
  void iapPurchase({
    required String productId,
    required double price,
    required String currency,
  }) => _log(Ev.iapPurchase, {
    'product_id': productId,
    'price': price,
    'currency': currency,
    'value': price,
  });

  /// A purchase failed or was cancelled.
  void iapFailed({required String productId, required String status}) =>
      _log(Ev.iapFailed, {'product_id': productId, 'status': status});

  /// Consent flow outcome.
  void consentResult({required String result}) =>
      _log(Ev.consentResult, {'result': result});

  /// Ad request.
  void adRequest({required String format, required String placement}) =>
      _log(Ev.adRequest, {'format': format, 'placement': placement});

  /// An ad request filled.
  void adLoaded({required String format}) =>
      _log(Ev.adLoaded, {'format': format});

  /// Ad impression with revenue from the paid-event callback.
  void adImpression({
    required String format,
    required String placement,
    required String network,
    required int valueMicros,
    required String currency,
  }) => _log(Ev.adImpression, {
    'format': format,
    'placement': placement,
    'network': network,
    'value_micros': valueMicros,
    'currency': currency,
    'value': valueMicros / 1e6,
  });

  /// Rewarded ad reward granted.
  void adRewardGranted({required String placement}) =>
      _log(Ev.adRewardGranted, {'placement': placement});

  /// Ad load or show failure.
  void adFailed({
    required String format,
    required String placement,
    required String error,
  }) => _log(Ev.adFailed, {
    'format': format,
    'placement': placement,
    'error': error.length > 90 ? error.substring(0, 90) : error,
  });

  /// Sets a user property.
  void userProperty(String name, String value) =>
      unawaited(_a.setUserProperty(name, value));
}
