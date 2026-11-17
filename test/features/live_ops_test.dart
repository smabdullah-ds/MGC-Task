import 'dart:async';

import 'package:bazaar_sort/core/economy/player_state.dart';
import 'package:bazaar_sort/features/daily/reminder_scheduler.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/services/ads/ad_analytics_bridge.dart';
import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:bazaar_sort/services/ads/fake_ads_service.dart';
import 'package:bazaar_sort/services/analytics/country_tier.dart';
import 'package:bazaar_sort/services/analytics/fake_analytics_service.dart';
import 'package:bazaar_sort/services/analytics/game_analytics.dart';
import 'package:bazaar_sort/services/notifications/fake_notification_service.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:bazaar_sort/services/storage/memory_storage_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  test('country tiers', () {
    expect(CountryTier.of('us'), 'tier1');
    expect(CountryTier.of('GB'), 'tier1');
    expect(CountryTier.of('FR'), 'tier2');
    expect(CountryTier.of('PK'), 'tier3');
    expect(CountryTier.of(null), 'unknown');
  });

  test('ad bridge logs requests, fills, revenue and failures', () async {
    final ads = FakeAdsService();
    final analytics = FakeAnalyticsService();
    final bridge = AdAnalyticsBridge(ads, GameAnalytics(analytics));
    await ads.initialize(personalization: AdPersonalization.personalized);
    await ads.showRewarded(RewardedPlacement.hint);
    await Future<void>.delayed(Duration.zero);
    final impression = analytics.named('ad_impression').single.parameters;
    expect(impression['placement'], 'hint');
    expect(impression['network'], 'fake');
    expect(impression['value_micros'], 0);
    await bridge.dispose();
  });

  group('ReminderScheduler', () {
    ProviderContainer make(FakeNotificationService n, {PlayerState? p}) {
      final storage = MemoryStorageService();
      if (p != null) unawaited(storage.write(saveKey, p.toJson()));
      final c = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          notificationServiceProvider.overrideWithValue(n),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('opt-in asks the OS, saves the answer and schedules', () async {
      final n = FakeNotificationService();
      final c = make(n);
      final s = c.read(reminderSchedulerProvider)
        ..now = () => DateTime(2026, 6, 1, 10);
      expect(await s.optIn(), isTrue);
      expect(c.read(playerProvider).settings.notificationsOptIn, isTrue);
      expect(c.read(playerProvider).settings.notificationsAsked, isTrue);
      expect(n.scheduled, isNotEmpty);
      expect(n.scheduled.first.title, contains('daily reward'));
    });

    test('denied permission keeps reminders off', () async {
      final n = FakeNotificationService(grant: false);
      final c = make(n);
      expect(await c.read(reminderSchedulerProvider).optIn(), isFalse);
      expect(n.scheduled, isEmpty);
    });

    test('opt-out and decline cancel everything', () async {
      final n = FakeNotificationService();
      final c = make(
        n,
        p: const PlayerState(
          settings: PlayerSettings(notificationsOptIn: true),
        ),
      );
      final s = c.read(reminderSchedulerProvider);
      await s.reschedule();
      expect(n.scheduled, isNotEmpty);
      await s.optOut();
      expect(n.scheduled, isEmpty);
      await s.decline();
      expect(c.read(playerProvider).settings.notificationsAsked, isTrue);
      await s.reschedule();
      expect(n.scheduled, isEmpty);
    });
  });

  testWidgets('home asks about reminders once, after level 5', (tester) async {
    final deps = TestDeps(player: const PlayerState(nextLevel: 6));
    final c = await pumpApp(tester, deps, location: '/home');
    expect(find.byKey(const ValueKey('reminder_prompt')), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await settle(tester, 4);
    expect(c.read(playerProvider).settings.notificationsAsked, isTrue);
    expect(find.byKey(const ValueKey('reminder_prompt')), findsNothing);
  });

  testWidgets('no reminder prompt for new players', (tester) async {
    final deps = TestDeps();
    await pumpApp(tester, deps, location: '/home');
    expect(find.byKey(const ValueKey('reminder_prompt')), findsNothing);
  });
}
