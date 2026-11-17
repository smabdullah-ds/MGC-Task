import 'package:bazaar_sort/services/iap/iap_types.dart';

/// In-app purchases (RevenueCat in production).
///
/// The service reports what the store says; granting coins and items is the
/// job of `PurchaseGranter`, which de-duplicates by transaction id.
abstract interface class IapService {
  /// Configures the SDK. Safe to call more than once.
  Future<void> initialize();

  /// Loads localized product info for [productIds]. Missing products are
  /// omitted. Returns an empty list offline.
  Future<List<StoreProduct>> loadProducts(List<String> productIds);

  /// Starts a purchase flow and completes with its outcome.
  Future<PurchaseRecord> purchase(String productId);

  /// Restores non-consumables and subscriptions.
  Future<List<PurchaseRecord>> restore();

  /// Current entitlements according to the store.
  Future<Entitlements> entitlements();

  /// Asynchronous updates: pending purchases completing, refunds, renewals.
  Stream<PurchaseRecord> get updates;
}
