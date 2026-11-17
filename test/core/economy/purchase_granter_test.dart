import 'package:bazaar_sort/core/economy/booster.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';
import 'package:bazaar_sort/core/economy/purchase_granter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const g = PurchaseGranter();
  final now = DateTime(2026, 5, 1, 10);

  PurchaseEvent bought(String id, String tx) => PurchaseEvent(
    productId: id,
    kind: PurchaseEventKind.purchased,
    transactionId: tx,
  );

  test('product table matches the launch prices', () {
    expect(Products.removeAds.usdPrice, 3.99);
    expect(Products.starterPack.usdPrice, 1.99);
    expect(
      [
        Products.coinsS,
        Products.coinsM,
        Products.coinsL,
        Products.coinsXl,
      ].map((p) => (p.usdPrice, p.coins)),
      [(0.99, 500), (4.99, 3000), (9.99, 7000), (19.99, 16000)],
    );
    expect(Products.vipWeekly.kind, ProductKind.subscription);
    expect(Products.byId('nope'), isNull);
  });

  test('coins pack grants once per transaction', () {
    final s1 = g.apply(const PlayerState(), bought('coins_m', 't1'), now)!;
    expect(s1.coins, 3000);
    expect(s1.purchases.isPayer, isTrue);
    expect(g.apply(s1, bought('coins_m', 't1'), now), isNull);
    expect(g.apply(s1, bought('coins_m', 't2'), now)!.coins, 6000);
  });

  test('purchases without a transaction id are not granted', () {
    expect(
      g.apply(
        const PlayerState(),
        const PurchaseEvent(
          productId: 'coins_s',
          kind: PurchaseEventKind.purchased,
        ),
        now,
      ),
      isNull,
    );
  });

  test('remove ads: 500 coins + entitlement; restore re-applies only the entitlement', () {
    final s = g.apply(const PlayerState(), bought('remove_ads', 't'), now)!;
    expect(s.coins, 500);
    expect(s.purchases.removeAds, isTrue);
    final fresh = g.apply(
      const PlayerState(),
      const PurchaseEvent(
        productId: 'remove_ads',
        kind: PurchaseEventKind.restored,
      ),
      now,
    )!;
    expect(fresh.purchases.removeAds, isTrue);
    expect(fresh.coins, 0);
  });

  test('restoring a consumable does nothing', () {
    expect(
      g.apply(
        const PlayerState(),
        const PurchaseEvent(
          productId: 'coins_l',
          kind: PurchaseEventKind.restored,
        ),
        now,
      ),
      isNull,
    );
  });

  test('starter pack: coins, 3 of each booster, no ads, marks bought', () {
    final s = g.apply(const PlayerState(), bought('starter_pack', 't'), now)!;
    expect(s.coins, 1500);
    for (final b in BoosterType.values) {
      expect(s.boosterCount(b), 3);
    }
    expect(s.purchases.removeAds, isTrue);
    expect(s.purchases.starterPackBought, isTrue);
  });

  test('VIP extends from the current expiry and refunds revoke it', () {
    final s1 = g.apply(const PlayerState(), bought('vip_weekly', 'a'), now)!;
    expect(s1.purchases.vipExpiresAt, now.add(const Duration(days: 7)));
    final s2 = g.apply(s1, bought('vip_weekly', 'b'), now)!;
    expect(s2.purchases.vipExpiresAt, now.add(const Duration(days: 14)));
    final refunded = g.apply(
      s2,
      const PurchaseEvent(
        productId: 'vip_weekly',
        kind: PurchaseEventKind.refunded,
      ),
      now,
    )!;
    expect(refunded.purchases.vipActiveAt(now), isFalse);
  });

  test('refunding remove ads turns ads back on, keeps coins', () {
    final s = g.apply(const PlayerState(), bought('remove_ads', 't'), now)!;
    final r = g.apply(
      s,
      const PurchaseEvent(
        productId: 'remove_ads',
        kind: PurchaseEventKind.refunded,
      ),
      now,
    )!;
    expect(r.purchases.removeAds, isFalse);
    expect(r.coins, 500);
  });

  test('VIP daily bonus once a day while active', () {
    final vip = g.apply(const PlayerState(), bought('vip_weekly', 't'), now)!;
    final (s1, booster) = g.vipDaily(vip, now)!;
    expect(s1.coins, 200);
    expect(s1.boosterCount(booster), 1);
    expect(g.vipDaily(s1, now), isNull);
    expect(g.vipDaily(s1, now.add(const Duration(days: 1))), isNotNull);
    expect(g.vipDaily(s1, now.add(const Duration(days: 8))), isNull);
    expect(g.vipDaily(const PlayerState(), now), isNull);
  });

  test('starter offer opens after level 15 for 48 hours', () {
    expect(
      g.openStarterOffer(const PlayerState(nextLevel: 15), now, minLevel: 15),
      isNull,
    );
    final open = g.openStarterOffer(
      const PlayerState(nextLevel: 16),
      now,
      minLevel: 15,
    )!;
    expect(g.openStarterOffer(open, now, minLevel: 15), isNull);
    expect(
      g.starterOfferRemaining(
        open,
        now.add(const Duration(hours: 47)),
        hours: 48,
      ),
      const Duration(hours: 1),
    );
    expect(
      g.starterOfferRemaining(
        open,
        now.add(const Duration(hours: 49)),
        hours: 48,
      ),
      isNull,
    );
    final afterBuy = g.apply(open, bought('starter_pack', 't'), now)!;
    expect(g.starterOfferRemaining(afterBuy, now, hours: 48), isNull);
    expect(
      g.starterOfferRemaining(const PlayerState(), now, hours: 48),
      isNull,
    );
  });

  test('unknown products are ignored', () {
    expect(g.apply(const PlayerState(), bought('mystery', 't'), now), isNull);
  });
}
