import 'dart:async';

import 'package:bazaar_sort/services/iap/iap_service.dart';
import 'package:bazaar_sort/services/iap/iap_types.dart';

/// Store that approves everything. Used in tests and when RevenueCat keys are
/// not configured. Prices mirror the launch price table in USD.
class FakeIapService implements IapService {
  /// Creates the fake. [nextStatus] controls the result of the next purchase.
  new({this.nextStatus = PurchaseStatus.purchased});

  /// Status the next [purchase] call returns.
  PurchaseStatus nextStatus;

  /// USD prices for known products.
  static const Map<String, double> usdPrices = <String, double>{
    'remove_ads': 3.99,
    'starter_pack': 1.99,
    'coins_s': 0.99,
    'coins_m': 4.99,
    'coins_l': 9.99,
    'coins_xl': 19.99,
    'booster_bundle': 2.99,
    'vip_weekly': 2.99,
  };

  static const Set<String> _restorable = <String>{
    'remove_ads',
    'starter_pack',
    'vip_weekly',
  };

  final StreamController<PurchaseRecord> _updates =
      StreamController<PurchaseRecord>.broadcast();
  final Set<String> _owned = <String>{};
  int _txCounter = 0;

  @override
  Stream<PurchaseRecord> get updates => _updates.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<StoreProduct>> loadProducts(List<String> productIds) async => [
    for (final id in productIds)
      if (usdPrices.containsKey(id))
        StoreProduct(
          id: id,
          title: id,
          priceString: '\$${usdPrices[id]!.toStringAsFixed(2)}',
          price: usdPrices[id]!,
          currencyCode: 'USD',
        ),
  ];

  @override
  Future<PurchaseRecord> purchase(String productId) async {
    final status = nextStatus;
    if (status == PurchaseStatus.purchased) _owned.add(productId);
    return PurchaseRecord(
      productId: productId,
      status: status,
      transactionId: status == PurchaseStatus.purchased
          ? 'fake-${++_txCounter}'
          : null,
      price: usdPrices[productId],
      currencyCode: 'USD',
    );
  }

  @override
  Future<List<PurchaseRecord>> restore() async => [
    for (final id in _owned.where(_restorable.contains))
      PurchaseRecord(
        productId: id,
        status: PurchaseStatus.restored,
        transactionId: 'restored-$id',
      ),
  ];

  @override
  Future<Entitlements> entitlements() async => Entitlements(
    removeAds: _owned.contains('remove_ads') || _owned.contains('starter_pack'),
    vipActive: _owned.contains('vip_weekly'),
  );

  /// Simulates a store-side update such as a refund (tests).
  void emit(PurchaseRecord record) {
    if (record.status == PurchaseStatus.refunded) {
      _owned.removeWhere((id) => id == record.productId);
    }
    _updates.add(record);
  }
}
