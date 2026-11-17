import 'package:bazaar_sort/core/economy/daily_progress.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/features/player/session_tasks.dart';
import 'package:bazaar_sort/services/iap/iap_types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  group('Shop', () {
    testWidgets('buying a coin pack grants coins and logs iap_purchase', (
      tester,
    ) async {
      final deps = TestDeps();
      final c = await pumpApp(tester, deps, location: '/shop');
      expect(deps.analytics.named('iap_view'), hasLength(1));
      expect(find.text(r'$4.99'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shop_coins_m')));
      await settle(tester);
      expect(c.read(playerProvider).coins, 3000);
      expect(
        deps.analytics.named('iap_purchase').single.parameters['product_id'],
        'coins_m',
      );
      expect(find.text('Thank you! Your purchase was added.'), findsOneWidget);
    });

    testWidgets('remove ads shows Owned and disables interstitials', (
      tester,
    ) async {
      final deps = TestDeps();
      final c = await pumpApp(tester, deps, location: '/shop');
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('shop_remove_ads')),
          matching: find.text(r'$3.99'),
        ),
      );
      await settle(tester);
      expect(c.read(playerProvider).purchases.removeAds, isTrue);
      expect(deps.ads.isInterstitialReady, isFalse);
      expect(deps.ads.isRewardedReady, isTrue);
      expect(find.text('Owned'), findsOneWidget);
    });

    testWidgets('pending and cancelled purchases grant nothing', (
      tester,
    ) async {
      final deps = TestDeps();
      deps.iap.nextStatus = PurchaseStatus.pending;
      final c = await pumpApp(tester, deps, location: '/shop');
      await tester.tap(find.byKey(const ValueKey('shop_coins_s')));
      await settle(tester);
      expect(c.read(playerProvider).coins, 0);
      expect(find.textContaining('Purchase pending'), findsOneWidget);

      deps.iap.nextStatus = PurchaseStatus.cancelled;
      await tester.tap(find.byKey(const ValueKey('shop_coins_s')));
      await settle(tester);
      expect(c.read(playerProvider).coins, 0);
      expect(deps.analytics.named('iap_failed'), hasLength(1));
    });

    testWidgets('restore purchases', (tester) async {
      final deps = TestDeps();
      await deps.iap.purchase('remove_ads');
      final c = await pumpApp(tester, deps, location: '/shop');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('shop_restore')),
        300,
      );
      await tester.tap(find.byKey(const ValueKey('shop_restore')));
      await settle(tester);
      expect(c.read(playerProvider).purchases.removeAds, isTrue);
      expect(
        c.read(playerProvider).coins,
        0,
        reason: 'restore grants no coins',
      );
      expect(find.text('Purchases restored.'), findsOneWidget);
    });

    testWidgets('starter pack card appears during its window', (tester) async {
      final deps = TestDeps(
        player: PlayerState(
          nextLevel: 20,
          purchases: PurchaseState(starterOfferStartedAt: DateTime.now()),
        ),
      );
      await pumpApp(tester, deps, location: '/shop');
      expect(find.byKey(const ValueKey('shop_starter_pack')), findsOneWidget);
      expect(find.textContaining('Ends in 47:59'), findsOneWidget);
    });
  });

  group('Bazaar', () {
    testWidgets('restoring an item spends coins and logs it', (tester) async {
      final deps = TestDeps(player: const PlayerState(coins: 400));
      final c = await pumpApp(tester, deps, location: '/bazaar');
      await tester.tap(find.byKey(const ValueKey('restore_spice_awning')));
      await settle(tester);
      expect(c.read(playerProvider).coins, 250);
      expect(c.read(playerProvider).restoredItems, contains('spice_awning'));
      expect(deps.analytics.named('bazaar_item_restored'), hasLength(1));
    });

    testWidgets('finishing an area shows the reward', (tester) async {
      final deps = TestDeps(
        player: const PlayerState(
          coins: 1000,
          restoredItems: {
            'spice_awning',
            'spice_sacks',
            'spice_scales',
            'spice_counter',
            'spice_lamps',
          },
        ),
      );
      final c = await pumpApp(tester, deps, location: '/bazaar');
      await tester.tap(find.byKey(const ValueKey('restore_spice_sign')));
      await settle(tester, 10);
      expect(
        find.byKey(const ValueKey('area_complete_dialog')),
        findsOneWidget,
      );
      expect(c.read(playerProvider).coins, 1000 - 290 + 200);
      expect(deps.analytics.named('area_complete'), hasLength(1));
    });

    testWidgets('unaffordable restore offers the shop', (tester) async {
      final deps = TestDeps(player: const PlayerState(coins: 10));
      await pumpApp(tester, deps, location: '/bazaar');
      await tester.tap(find.byKey(const ValueKey('restore_spice_awning')));
      await settle(tester, 3);
      expect(find.text('Not enough coins'), findsOneWidget);
    });
  });

  group('Daily', () {
    testWidgets('claim the login reward once', (tester) async {
      final deps = TestDeps();
      final c = await pumpApp(tester, deps, location: '/daily');
      await tester.tap(find.byKey(const ValueKey('daily_claim')));
      await settle(tester);
      expect(c.read(playerProvider).coins, DailyProgress.calendar[0].coins);
      expect(deps.analytics.named('daily_reward_claimed'), hasLength(1));
      expect(find.text('Come back tomorrow!'), findsOneWidget);
    });

    testWidgets('free spin needs a rewarded ad and pays once', (tester) async {
      final deps = TestDeps();
      final c = await pumpApp(tester, deps, location: '/daily');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('daily_spin')),
        300,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('daily_spin')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('daily_spin')),
        warnIfMissed: true,
      );
      await settle(tester, 30);
      expect(deps.ads.rewardedShown, hasLength(1));
      expect(c.read(playerProvider).daily.lastFreeSpin, isNotNull);
      expect(find.text('Spin again tomorrow'), findsOneWidget);
    });
  });

  testWidgets('home shows level, coins and bazaar progress', (tester) async {
    final deps = TestDeps(
      player: const PlayerState(
        nextLevel: 7,
        coins: 1234,
        restoredItems: {'spice_awning'},
      ),
    );
    await pumpApp(tester, deps, location: '/home');
    expect(find.text('Play – Level 7'), findsOneWidget);
    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('1 of 6 restored'), findsOneWidget);
  });

  testWidgets('session tasks grant VIP daily coins once', (tester) async {
    final deps = TestDeps(
      player: PlayerState(
        purchases: PurchaseState(
          vipExpiresAt: DateTime.now().add(const Duration(days: 3)),
        ),
      ),
    );
    final c = await pumpApp(tester, deps, location: '/home');
    final tasks = c.read(sessionTasksProvider);
    expect(await tasks.onAppOpen(), 200);
    expect(await tasks.onAppOpen(), 0);
    expect(c.read(playerProvider).coins, 200);
  });
}
