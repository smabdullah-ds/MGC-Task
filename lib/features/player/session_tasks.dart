import 'package:bazaar_sort/core/economy/purchase_granter.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/services/analytics/game_analytics.dart';
import 'package:bazaar_sort/services/remote_config/tuning.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Housekeeping run when the app opens or returns to the foreground.
class SessionTasks {
  /// Creates the tasks.
  new(this._ref);

  final Ref _ref;

  /// Clock (overridable in tests).
  DateTime Function() now = DateTime.now;

  /// Grants the VIP daily bonus, opens the starter-pack window when due and
  /// reconciles entitlements with the store. Returns the VIP coins granted
  /// (0 if none) so the UI can celebrate them.
  Future<int> onAppOpen() async {
    final cfg = _ref.read(economyConfigProvider);
    final granter = PurchaseGranter(vipDailyCoins: cfg.vipDailyCoins);
    final store = _ref.read(playerProvider.notifier);
    final analytics = _ref.read(gameAnalyticsProvider);
    final at = now();

    await _syncEntitlements();

    var vipCoins = 0;
    final vip = granter.vipDaily(store.current, at);
    if (vip != null) {
      await store.update((_) => vip.$1);
      vipCoins = cfg.vipDailyCoins;
      analytics.coinsEarned(amount: vipCoins, source: 'vip_daily');
    }

    await store.update(
      (s) => granter.openStarterOffer(s, at, minLevel: cfg.starterPackMinLevel),
    );

    final p = store.current.purchases;
    analytics
      ..userProperty(UserProp.payer, p.isPayer ? 'yes' : 'no')
      ..userProperty(
        UserProp.adFree,
        p.removeAds || p.vipActiveAt(at) ? 'yes' : 'no',
      );
    if (p.removeAds || p.vipActiveAt(at)) {
      _ref.read(adsServiceProvider).disableNonRewarded();
    }
    return vipCoins;
  }

  Future<void> _syncEntitlements() async {
    try {
      final e = await _ref.read(iapServiceProvider).entitlements();
      final store = _ref.read(playerProvider.notifier);
      final at = now();
      await store.update((s) {
        final p = s.purchases;
        final needsAds = e.removeAds && !p.removeAds;
        final needsVip = e.vipActive && !p.vipActiveAt(at);
        if (!needsAds && !needsVip) return null;
        return s.copyWith(
          purchases: p.copyWith(
            removeAds: needsAds ? true : null,
            vipExpiresAt: needsVip ? at.add(const Duration(days: 1)) : null,
          ),
        );
      });
    } on Object {
      // Offline: keep the saved entitlements.
    }
  }
}

/// App-open housekeeping.
final sessionTasksProvider = Provider<SessionTasks>(SessionTasks.new);
