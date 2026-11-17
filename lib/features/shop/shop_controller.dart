import 'dart:async';

import 'package:bazaar_sort/core/economy/purchase_granter.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/services/analytics/game_analytics.dart';
import 'package:bazaar_sort/services/iap/iap_types.dart';
import 'package:bazaar_sort/services/remote_config/tuning.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of a purchase attempt, for UI feedback.
enum ShopOutcome { granted, pending, cancelled, failed, duplicate }

/// Purchase flows: buy, restore, and asynchronous store updates (pending
/// purchases completing, refunds). Every grant goes through
/// [PurchaseGranter], so a transaction is applied at most once.
class ShopController {
  /// Creates the controller.
  new(this._ref);

  final Ref _ref;
  StreamSubscription<PurchaseRecord>? _updates;

  PurchaseGranter get _granter => PurchaseGranter(
    vipDailyCoins: _ref.read(economyConfigProvider).vipDailyCoins,
  );

  GameAnalytics get _analytics => _ref.read(gameAnalyticsProvider);

  /// Localized products for the shop, in catalog order. Empty offline.
  Future<List<StoreProduct>> products() async {
    try {
      final loaded = await _ref.read(iapServiceProvider).loadProducts([
        for (final p in Products.all) p.id,
      ]);
      final byId = {for (final p in loaded) p.id: p};
      return [
        for (final p in Products.all)
          if (byId[p.id] != null) byId[p.id]!,
      ];
    } on Object {
      return const [];
    }
  }

  /// Subscribes to store updates. Safe to call more than once.
  void listenForUpdates() {
    _updates ??= _ref
        .read(iapServiceProvider)
        .updates
        .listen((r) => unawaited(_applyRecord(r)));
  }

  /// Buys [productId].
  Future<ShopOutcome> buy(String productId) async {
    final iap = _ref.read(iapServiceProvider);
    PurchaseRecord record;
    try {
      record = await iap.purchase(productId);
    } on Object catch (e, st) {
      unawaited(
        _ref
            .read(analyticsServiceProvider)
            .recordError(e, st, reason: 'purchase $productId'),
      );
      _analytics.iapFailed(productId: productId, status: 'exception');
      return ShopOutcome.failed;
    }
    return await _applyRecord(record);
  }

  /// Restores purchases. Returns how many entitlements were re-applied.
  Future<int> restore() async {
    final records = await _ref.read(iapServiceProvider).restore();
    var count = 0;
    for (final r in records) {
      if (await _applyRecord(r) == ShopOutcome.granted) count++;
    }
    return count;
  }

  Future<ShopOutcome> _applyRecord(PurchaseRecord r) async {
    final kind = switch (r.status) {
      PurchaseStatus.purchased => PurchaseEventKind.purchased,
      PurchaseStatus.restored => PurchaseEventKind.restored,
      PurchaseStatus.refunded => PurchaseEventKind.refunded,
      PurchaseStatus.pending => null,
      PurchaseStatus.cancelled => null,
      PurchaseStatus.failed => null,
    };
    if (kind == null) {
      if (r.status != PurchaseStatus.pending) {
        _analytics.iapFailed(productId: r.productId, status: r.status.name);
      }
      return switch (r.status) {
        PurchaseStatus.pending => ShopOutcome.pending,
        PurchaseStatus.cancelled => ShopOutcome.cancelled,
        _ => ShopOutcome.failed,
      };
    }
    final event = PurchaseEvent(
      productId: r.productId,
      kind: kind,
      transactionId: r.transactionId,
    );
    final store = _ref.read(playerProvider.notifier);
    final next = await store.update(
      (s) => _granter.apply(s, event, DateTime.now()),
    );
    if (next == null) return ShopOutcome.duplicate;

    if (next.purchases.removeAds) {
      _ref.read(adsServiceProvider).disableNonRewarded();
    }
    if (kind == PurchaseEventKind.purchased) {
      final product = Products.byId(r.productId);
      _analytics
        ..iapPurchase(
          productId: r.productId,
          price: r.price ?? product?.usdPrice ?? 0,
          currency: r.currencyCode ?? 'USD',
        )
        ..userProperty(UserProp.payer, 'yes');
      if ((product?.coins ?? 0) > 0) {
        _analytics.coinsEarned(amount: product!.coins, source: 'iap');
      }
    }
    _analytics.userProperty(
      UserProp.adFree,
      next.purchases.removeAds ? 'yes' : 'no',
    );
    return ShopOutcome.granted;
  }

  /// Stops listening.
  Future<void> dispose() async => await _updates?.cancel();
}

/// One shop controller per app.
final shopControllerProvider = Provider<ShopController>((ref) {
  final c = ShopController(ref);
  ref.onDispose(() => unawaited(c.dispose()));
  return c;
});
