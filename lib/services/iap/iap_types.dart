import 'package:flutter/foundation.dart';

/// A product as the store presents it, with a localized price string.
@immutable
class StoreProduct {
  /// Creates a store product.
  const new({
    required this.id,
    required this.title,
    required this.priceString,
    required this.price,
    required this.currencyCode,
  });

  /// Product identifier, e.g. `coins_m`.
  final String id;

  /// Store-localized title.
  final String title;

  /// Store-localized price, e.g. `€4,99`.
  final String priceString;

  /// Numeric price in [currencyCode].
  final double price;

  /// ISO 4217 currency code.
  final String currencyCode;
}

/// Outcome of a purchase attempt or a later store update.
enum PurchaseStatus {
  /// Paid and should be granted.
  purchased,

  /// Awaiting payment (e.g. cash / parental approval). Do not grant yet.
  pending,

  /// User cancelled. Nothing to do.
  cancelled,

  /// Revoked by the store. Entitlements must be removed.
  refunded,

  /// Previously bought; returned by restore.
  restored,

  /// Something went wrong.
  failed,
}

/// A single transaction reported by the store.
@immutable
class PurchaseRecord {
  /// Creates a record.
  const new({
    required this.productId,
    required this.status,
    this.transactionId,
    this.price,
    this.currencyCode,
    this.errorMessage,
  });

  /// Product purchased.
  final String productId;

  /// What happened.
  final PurchaseStatus status;

  /// Store transaction id; the idempotency key for grants.
  final String? transactionId;

  /// Price paid, if known.
  final double? price;

  /// Currency of [price].
  final String? currencyCode;

  /// Error description when [status] is [PurchaseStatus.failed].
  final String? errorMessage;
}

/// Active subscription / non-consumable state reported by the store.
@immutable
class Entitlements {
  /// Creates entitlements.
  const new({this.removeAds = false, this.vipActive = false});

  /// Whether `remove_ads` (or the starter pack, which includes it) is owned.
  final bool removeAds;

  /// Whether the VIP weekly subscription is active.
  final bool vipActive;
}
