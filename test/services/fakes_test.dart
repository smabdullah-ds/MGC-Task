import 'package:bazaar_sort/config/remote_config_defaults.dart';
import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:bazaar_sort/services/ads/fake_ads_service.dart';
import 'package:bazaar_sort/services/analytics/fake_analytics_service.dart';
import 'package:bazaar_sort/services/consent/fake_consent_service.dart';
import 'package:bazaar_sort/services/iap/fake_iap_service.dart';
import 'package:bazaar_sort/services/iap/iap_types.dart';
import 'package:bazaar_sort/services/notifications/fake_notification_service.dart';
import 'package:bazaar_sort/services/notifications/notification_service.dart';
import 'package:bazaar_sort/services/remote_config/fake_remote_config_service.dart';
import 'package:bazaar_sort/services/storage/memory_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeAdsService', () {
    test('grants rewards and emits events when filled', () async {
      final ads = FakeAdsService();
      await ads.initialize(personalization: AdPersonalization.personalized);
      final events = <AdEvent>[];
      ads.events.listen(events.add);
      expect(await ads.showRewarded(RewardedPlacement.hint), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(events.map((e) => e.type), [
        AdEventType.impression,
        AdEventType.rewardGranted,
      ]);
    });

    test('no fill returns false', () async {
      final ads = FakeAdsService(fill: false);
      await ads.initialize(personalization: AdPersonalization.personalized);
      expect(await ads.showRewarded(RewardedPlacement.hint), isFalse);
      expect(await ads.showInterstitial('x'), isFalse);
    });

    test('disableNonRewarded keeps rewarded ads', () async {
      final ads = FakeAdsService();
      await ads.initialize(personalization: AdPersonalization.personalized);
      ads.disableNonRewarded();
      expect(ads.isInterstitialReady, isFalse);
      expect(ads.isRewardedReady, isTrue);
    });

    test('no consent means no ads', () async {
      final ads = FakeAdsService();
      await ads.initialize(personalization: AdPersonalization.none);
      expect(ads.isRewardedReady, isFalse);
    });
  });

  group('FakeIapService', () {
    test('purchase yields unique transaction ids', () async {
      final iap = FakeIapService();
      final a = await iap.purchase('coins_s');
      final b = await iap.purchase('coins_s');
      expect(a.status, PurchaseStatus.purchased);
      expect(a.transactionId, isNot(b.transactionId));
    });

    test('restore returns only non-consumables', () async {
      final iap = FakeIapService();
      await iap.purchase('coins_s');
      await iap.purchase('remove_ads');
      final restored = await iap.restore();
      expect(restored.map((r) => r.productId), ['remove_ads']);
      expect((await iap.entitlements()).removeAds, isTrue);
    });

    test('refund removes entitlement', () async {
      final iap = FakeIapService();
      await iap.purchase('vip_weekly');
      iap.emit(
        const PurchaseRecord(
          productId: 'vip_weekly',
          status: PurchaseStatus.refunded,
        ),
      );
      expect((await iap.entitlements()).vipActive, isFalse);
    });

    test('loadProducts has localized prices', () async {
      final products = await FakeIapService().loadProducts(['coins_m', 'x']);
      expect(products.single.priceString, r'$4.99');
    });
  });

  test('FakeRemoteConfigService falls back to defaults', () {
    final rc = FakeRemoteConfigService({RcKeys.coinsBase: '35'});
    expect(rc.getInt(RcKeys.coinsBase), 35);
    expect(rc.getInt(RcKeys.coinsPerStar), 10);
    expect(rc.getDouble(RcKeys.starThreeRatio), 1.2);
    expect(rc.getBool(RcKeys.bannerBazaarEnabled), isFalse);
    expect(rc.getString(RcKeys.experimentGroup), 'control');
    expect(rc.getInt('missing'), 0);
  });

  test('MemoryStorageService round-trips JSON', () async {
    final storage = MemoryStorageService();
    await storage.write('k', {
      'a': 1,
      'b': ['x'],
    });
    expect(storage.read('k'), {
      'a': 1,
      'b': ['x'],
    });
    await storage.delete('k');
    expect(storage.read('k'), isNull);
  });

  test('FakeAnalyticsService records events', () async {
    final analytics = FakeAnalyticsService();
    await analytics.logEvent('level_start', {'level': 1});
    expect(analytics.named('level_start').single.parameters['level'], 1);
  });

  test('FakeConsentService counts option form opens', () async {
    final consent = FakeConsentService();
    await consent.showPrivacyOptions();
    expect(consent.optionsShown, 1);
  });

  test('FakeNotificationService replaces schedule', () async {
    final n = FakeNotificationService();
    await n.replaceSchedule([
      ScheduledNotification(
        kind: NotificationKind.dailyRewardReady,
        when: DateTime(2030),
        title: 't',
        body: 'b',
      ),
    ]);
    expect(n.scheduled, hasLength(1));
    await n.cancelAll();
    expect(n.scheduled, isEmpty);
  });
}
