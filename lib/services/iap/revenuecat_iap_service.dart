import 'dart:async';
import 'dart:io' show Platform;

import 'package:bazaar_sort/core/economy/purchase_granter.dart';
import 'package:bazaar_sort/services/iap/iap_service.dart';
import 'package:bazaar_sort/services/iap/iap_types.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

/// [IapService] on RevenueCat.
///
/// RevenueCat dashboard setup (see README → "RevenueCat"):
/// * products: `remove_ads`, `starter_pack`, `coins_s/m/l/xl`,
///   `booster_bundle` (one-time) and `vip_weekly` (weekly subscription);
/// * entitlements: [noAdsEntitlement] attached to `remove_ads` and
///   `starter_pack`; [vipEntitlement] attached to `vip_weekly`.
class RevenueCatIapService implements IapService {
  /// Creates the service with a public SDK key.
  new({required this.apiKey});

  /// Public SDK key for this platform.
  final String apiKey;

  /// Entitlement unlocked by remove-ads and the starter pack.
  static const String noAdsEntitlement = 'no_ads';

  /// Entitlement unlocked by the VIP subscription.
  static const String vipEntitlement = 'vip';

  final StreamController<PurchaseRecord> _updates =
      StreamController<PurchaseRecord>.broadcast();
  final Map<String, rc.StoreProduct> _cache = {};
  final Set<String> _seenTransactions = {};
  bool _configured = false;
  bool _hadNoAds = false;
  bool _hadVip = false;

  @override
  Stream<PurchaseRecord> get updates => _updates.stream;

  @override
  Future<void> initialize() async {
    if (_configured) return;
    await rc.Purchases.configure(rc.PurchasesConfiguration(apiKey));
    _configured = true;
    final info = await rc.Purchases.getCustomerInfo();
    _remember(info);
    rc.Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
  }

  void _remember(rc.CustomerInfo info) {
    _seenTransactions.addAll(
      info.nonSubscriptionTransactions.map((t) => t.transactionIdentifier),
    );
    _hadNoAds = info.entitlements.active.containsKey(noAdsEntitlement);
    _hadVip = info.entitlements.active.containsKey(vipEntitlement);
  }

  /// Turns RevenueCat updates into records: purchases that completed later
  /// (pending → paid) and entitlements that disappeared (refund / expiry).
  void _onCustomerInfo(rc.CustomerInfo info) {
    for (final t in info.nonSubscriptionTransactions) {
      if (_seenTransactions.add(t.transactionIdentifier)) {
        _updates.add(
          PurchaseRecord(
            productId: t.productIdentifier,
            status: PurchaseStatus.purchased,
            transactionId: t.transactionIdentifier,
          ),
        );
      }
    }
    final noAds = info.entitlements.active.containsKey(noAdsEntitlement);
    final vip = info.entitlements.active.containsKey(vipEntitlement);
    if (_hadNoAds && !noAds) {
      _updates.add(
        PurchaseRecord(
          productId: Products.removeAds.id,
          status: PurchaseStatus.refunded,
        ),
      );
    }
    if (_hadVip && !vip) {
      _updates.add(
        PurchaseRecord(
          productId: Products.vipWeekly.id,
          status: PurchaseStatus.refunded,
        ),
      );
    }
    _hadNoAds = noAds;
    _hadVip = vip;
  }

  @override
  Future<List<StoreProduct>> loadProducts(List<String> productIds) async {
    final subs = [
      for (final id in productIds)
        if (Products.byId(id)?.kind == ProductKind.subscription) id,
    ];
    final others = [
      for (final id in productIds)
        if (!subs.contains(id)) id,
    ];
    final results = await Future.wait([
      if (others.isNotEmpty)
        rc.Purchases.getProducts(
          others,
          productCategory: rc.ProductCategory.nonSubscription,
        ),
      if (subs.isNotEmpty) rc.Purchases.getProducts(subs),
    ]);
    final out = <StoreProduct>[];
    for (final p in results.expand((r) => r)) {
      // Android subscription ids can come back as "id:base-plan".
      final id = p.identifier.split(':').first;
      _cache[id] = p;
      out.add(
        StoreProduct(
          id: id,
          title: p.title,
          priceString: p.priceString,
          price: p.price,
          currencyCode: p.currencyCode,
        ),
      );
    }
    return out;
  }

  @override
  Future<PurchaseRecord> purchase(String productId) async {
    try {
      var product = _cache[productId];
      if (product == null) {
        await loadProducts([productId]);
        product = _cache[productId];
      }
      if (product == null) {
        return PurchaseRecord(
          productId: productId,
          status: PurchaseStatus.failed,
          errorMessage: 'product not found',
        );
      }
      final result = await rc.Purchases.purchase(
        rc.PurchaseParams.storeProduct(product),
      );
      final tx = result.storeTransaction.transactionIdentifier;
      _seenTransactions.add(tx);
      _remember(result.customerInfo);
      return PurchaseRecord(
        productId: productId,
        status: PurchaseStatus.purchased,
        transactionId: tx,
        price: product.price,
        currencyCode: product.currencyCode,
      );
    } on PlatformException catch (e) {
      final code = rc.PurchasesErrorHelper.getErrorCode(e);
      return PurchaseRecord(
        productId: productId,
        status: switch (code) {
          rc.PurchasesErrorCode.purchaseCancelledError =>
            PurchaseStatus.cancelled,
          rc.PurchasesErrorCode.paymentPendingError => PurchaseStatus.pending,
          rc.PurchasesErrorCode.productAlreadyPurchasedError =>
            PurchaseStatus.restored,
          _ => PurchaseStatus.failed,
        },
        errorMessage: e.message,
      );
    }
  }

  @override
  Future<List<PurchaseRecord>> restore() async {
    final info = await rc.Purchases.restorePurchases();
    _remember(info);
    final active = info.entitlements.active;
    return [
      if (active.containsKey(noAdsEntitlement))
        PurchaseRecord(
          productId: Products.removeAds.id,
          status: PurchaseStatus.restored,
        ),
      if (active.containsKey(vipEntitlement))
        PurchaseRecord(
          productId: Products.vipWeekly.id,
          status: PurchaseStatus.restored,
        ),
    ];
  }

  @override
  Future<Entitlements> entitlements() async {
    final info = await rc.Purchases.getCustomerInfo();
    final active = info.entitlements.active;
    return Entitlements(
      removeAds: active.containsKey(noAdsEntitlement),
      vipActive: active.containsKey(vipEntitlement),
    );
  }

  /// The SDK key for the current platform from [android] / [ios].
  static String keyForPlatform({
    required String android,
    required String ios,
  }) => Platform.isIOS ? ios : android;
}
