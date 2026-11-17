import 'package:bazaar_sort/core/economy/booster.dart';
import 'package:bazaar_sort/core/economy/daily_progress.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';

/// How a product behaves in the store.
enum ProductKind { consumable, nonConsumable, subscription }

/// What a product grants.
final class ProductInfo {
  /// Creates a product definition.
  const new({
    required this.id,
    required this.kind,
    required this.usdPrice,
    this.coins = 0,
    this.boostersEach = 0,
    this.removeAds = false,
    this.vip = false,
  });

  /// Store product id.
  final String id;

  /// Store behaviour.
  final ProductKind kind;

  /// Reference price (analytics fallback; the store's localized price is
  /// always what the player sees).
  final double usdPrice;

  /// Coins granted.
  final int coins;

  /// Charges of *each* booster granted.
  final int boostersEach;

  /// Turns off interstitials and banners.
  final bool removeAds;

  /// Starts or extends VIP.
  final bool vip;
}

/// The launch product line-up.
abstract final class Products {
  static const removeAds = ProductInfo(
    id: 'remove_ads',
    kind: ProductKind.nonConsumable,
    usdPrice: 3.99,
    coins: 500,
    removeAds: true,
  );
  static const starterPack = ProductInfo(
    id: 'starter_pack',
    kind: ProductKind.nonConsumable,
    usdPrice: 1.99,
    coins: 1500,
    boostersEach: 3,
    removeAds: true,
  );
  static const coinsS = ProductInfo(
    id: 'coins_s',
    kind: ProductKind.consumable,
    usdPrice: 0.99,
    coins: 500,
  );
  static const coinsM = ProductInfo(
    id: 'coins_m',
    kind: ProductKind.consumable,
    usdPrice: 4.99,
    coins: 3000,
  );
  static const coinsL = ProductInfo(
    id: 'coins_l',
    kind: ProductKind.consumable,
    usdPrice: 9.99,
    coins: 7000,
  );
  static const coinsXl = ProductInfo(
    id: 'coins_xl',
    kind: ProductKind.consumable,
    usdPrice: 19.99,
    coins: 16000,
  );
  static const boosterBundle = ProductInfo(
    id: 'booster_bundle',
    kind: ProductKind.consumable,
    usdPrice: 2.99,
    boostersEach: 3,
  );
  static const vipWeekly = ProductInfo(
    id: 'vip_weekly',
    kind: ProductKind.subscription,
    usdPrice: 2.99,
    vip: true,
  );

  /// Every product.
  static const List<ProductInfo> all = [
    removeAds,
    starterPack,
    coinsS,
    coinsM,
    coinsL,
    coinsXl,
    boosterBundle,
    vipWeekly,
  ];

  /// Product by id, or `null`.
  static ProductInfo? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// What the store reported.
enum PurchaseEventKind { purchased, restored, refunded }

/// A store event, independent of any SDK.
final class PurchaseEvent {
  /// Creates an event.
  const new({required this.productId, required this.kind, this.transactionId});

  /// Product.
  final String productId;

  /// What happened.
  final PurchaseEventKind kind;

  /// Store transaction id (idempotency key for paid grants).
  final String? transactionId;
}

/// Applies store events to the player, exactly once each.
///
/// * **Purchased**: grants content and records the transaction id; the same
///   id is never granted again (store retries, app restarts, duplicate
///   listener callbacks).
/// * **Restored**: re-applies *entitlements* only (remove-ads, VIP) — never
///   coins or boosters, so restoring can't be farmed.
/// * **Refunded**: removes the entitlement. Coins already spent are not
///   clawed back (a negative balance would be worse for everyone).
final class PurchaseGranter {
  /// Creates the granter. [vipDuration] is the length of one VIP period.
  const new({
    this.vipDuration = const Duration(days: 7),
    this.vipDailyCoins = 200,
  });

  /// One subscription period.
  final Duration vipDuration;

  /// VIP daily coin bonus.
  final int vipDailyCoins;

  /// Applies [event]. Returns `null` when nothing changes (duplicate,
  /// unknown product).
  PlayerState? apply(PlayerState s, PurchaseEvent event, DateTime now) {
    final product = Products.byId(event.productId);
    if (product == null) return null;
    switch (event.kind) {
      case PurchaseEventKind.purchased:
        final tx = event.transactionId;
        if (tx == null || s.purchases.grantedTransactions.contains(tx)) {
          return null;
        }
        return _grantContent(s, product, now).copyWith(
          purchases: _entitle(s.purchases, product, now).copyWith(
            grantedTransactions: {...s.purchases.grantedTransactions, tx},
            isPayer: true,
            starterPackBought:
                s.purchases.starterPackBought ||
                product == Products.starterPack,
          ),
        );
      case PurchaseEventKind.restored:
        if (!product.removeAds && !product.vip) return null;
        final p = _entitle(s.purchases, product, now);
        return s.copyWith(
          purchases: p.copyWith(
            starterPackBought:
                p.starterPackBought || product == Products.starterPack,
          ),
        );
      case PurchaseEventKind.refunded:
        return s.copyWith(
          purchases: s.purchases.copyWith(
            removeAds: product.removeAds ? false : null,
            clearVip: product.vip,
          ),
        );
    }
  }

  PlayerState _grantContent(PlayerState s, ProductInfo p, DateTime now) {
    final boosters = {...s.boosters};
    if (p.boostersEach > 0) {
      for (final b in BoosterType.values) {
        boosters[b] = (boosters[b] ?? 0) + p.boostersEach;
      }
    }
    return s.copyWith(coins: s.coins + p.coins, boosters: boosters);
  }

  PurchaseState _entitle(PurchaseState ps, ProductInfo p, DateTime now) {
    var next = ps;
    if (p.removeAds) next = next.copyWith(removeAds: true);
    if (p.vip) {
      final base = ps.vipActiveAt(now) ? ps.vipExpiresAt! : now;
      next = next.copyWith(vipExpiresAt: base.add(vipDuration));
    }
    return next;
  }

  /// Grants the VIP daily bonus (coins + one random booster) once per day
  /// while VIP is active. `null` when not due.
  (PlayerState, BoosterType)? vipDaily(PlayerState s, DateTime now) {
    final today = DailyProgress.dayKey(now);
    if (!s.purchases.vipActiveAt(now) || s.purchases.lastVipGrant == today) {
      return null;
    }
    final booster = BoosterType.values[now.day % BoosterType.values.length];
    return (
      s.copyWith(
        coins: s.coins + vipDailyCoins,
        boosters: {...s.boosters, booster: s.boosterCount(booster) + 1},
        purchases: s.purchases.copyWith(lastVipGrant: today),
      ),
      booster,
    );
  }

  /// Opens the 48 h starter-pack window the first time the player passes
  /// [minLevel]. `null` when nothing changes.
  PlayerState? openStarterOffer(
    PlayerState s,
    DateTime now, {
    required int minLevel,
  }) {
    if (s.purchases.starterPackBought ||
        s.purchases.starterOfferStartedAt != null ||
        s.nextLevel <= minLevel) {
      return null;
    }
    return s.copyWith(
      purchases: s.purchases.copyWith(starterOfferStartedAt: now),
    );
  }

  /// Time left on the starter-pack offer, or `null` if it isn't showing.
  Duration? starterOfferRemaining(
    PlayerState s,
    DateTime now, {
    required int hours,
  }) {
    final start = s.purchases.starterOfferStartedAt;
    if (start == null || s.purchases.starterPackBought) return null;
    final left = start.add(Duration(hours: hours)).difference(now);
    return left.isNegative ? null : left;
  }
}
