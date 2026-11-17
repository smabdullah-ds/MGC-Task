import 'package:bazaar_sort/core/economy/booster.dart';
import 'package:bazaar_sort/core/economy/economy_config.dart';
import 'package:bazaar_sort/core/economy/progression.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:bazaar_sort/services/ads/ads_service.dart';
import 'package:bazaar_sort/services/analytics/game_analytics.dart';

/// Ways to pay for something in a level.
enum PaySource { inventory, coins, ad }

/// Pays for boosters and fail-screen continues. Every successful payment is
/// saved and logged (`booster_used` / `coins_spent`); applying the effect to
/// the board is the caller's job.
class BoosterCoordinator {
  /// Creates a coordinator.
  new({
    required this.store,
    required this.ads,
    required this.analytics,
    required this.config,
    required this.level,
    this.onRewardedShown,
  });

  /// Player store.
  final PlayerStore store;

  /// Ads.
  final AdsService ads;

  /// Analytics.
  final GameAnalytics analytics;

  /// Prices.
  final EconomyConfig config;

  /// Level being played (analytics).
  final int level;

  /// Called after a rewarded ad was watched (pauses interstitials).
  final void Function()? onRewardedShown;

  Progression get _progression => Progression(config);

  /// Owned charges of [type].
  int owned(BoosterType type) => store.current.boosterCount(type);

  /// Whether [cost] coins are affordable.
  bool canAfford(int cost) => store.current.coins >= cost;

  /// Whether a rewarded ad can be shown right now.
  bool get adReady => ads.isRewardedReady;

  /// Pays for [type] with [source]. Returns whether payment succeeded.
  Future<bool> payFor(BoosterType type, PaySource source) => _pay(
    name: _boosterName(type),
    source: source,
    coins: config.priceOf(type),
    placement: _placementFor(type),
    inventory: type,
  );

  /// Pays for extra moves (move-limited fail screen).
  Future<bool> payForExtraMoves(PaySource source) => _pay(
    name: 'extra_moves',
    source: source,
    coins: config.priceExtraMoves,
    placement: RewardedPlacement.extraMoves,
  );

  Future<bool> _pay({
    required String name,
    required PaySource source,
    required int coins,
    required RewardedPlacement placement,
    BoosterType? inventory,
  }) async {
    switch (source) {
      case PaySource.inventory:
        if (inventory == null) return false;
        final s = await store.update(
          (p) => _progression.useBooster(p, inventory),
        );
        if (s == null) return false;
      case PaySource.coins:
        final s = await store.update((p) => _progression.spend(p, coins));
        if (s == null) return false;
        analytics.coinsSpent(amount: coins, sink: name);
      case PaySource.ad:
        analytics.adRequest(format: 'rewarded', placement: placement.name);
        final ok = await ads.showRewarded(placement);
        if (!ok) return false;
        onRewardedShown?.call();
        analytics.adRewardGranted(placement: placement.name);
    }
    analytics.boosterUsed(type: name, source: source.name, level: level);
    return true;
  }

  static String _boosterName(BoosterType t) => switch (t) {
    BoosterType.undo => 'undo',
    BoosterType.extraShelf => 'extra_shelf',
    BoosterType.hint => 'hint',
    BoosterType.shuffle => 'shuffle',
  };

  static RewardedPlacement _placementFor(BoosterType t) => switch (t) {
    BoosterType.undo => RewardedPlacement.undoRefill,
    BoosterType.extraShelf => RewardedPlacement.extraShelf,
    BoosterType.hint => RewardedPlacement.hint,
    BoosterType.shuffle => RewardedPlacement.shuffle,
  };
}
