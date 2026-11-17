import 'package:bazaar_sort/app/app.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';
import 'package:bazaar_sort/features/gameplay/board/picture_cache.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/features/settings/locales.dart';
import 'package:bazaar_sort/features/settings/settings_screen.dart';
import 'package:bazaar_sort/services/audio/feedback_service.dart';
import 'package:bazaar_sort/services/consent/fake_consent_service.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  group('Settings', () {
    testWidgets('toggles persist, configure audio and log', (tester) async {
      final deps = TestDeps();
      final c = await pumpApp(tester, deps, location: '/settings');
      await tester.tap(find.byKey(const ValueKey('settings_sound')));
      await settle(tester, 3);
      await tester.tap(find.byKey(const ValueKey('settings_colorblind')));
      await settle(tester, 3);
      final s = c.read(playerProvider).settings;
      expect(s.sound, isFalse);
      expect(s.colorblind, isTrue);
      expect(deps.storage.read(saveKey), isNotNull);
      expect(deps.analytics.named('settings_changed'), hasLength(2));
      deps.feedback.play(Sfx.tap);
      expect(deps.feedback.played, isEmpty, reason: 'sound is off');
    });

    testWidgets('manage consent reopens the privacy options form', (
      tester,
    ) async {
      final deps = TestDeps();
      final consent = FakeConsentService();
      tester.view
        ..physicalSize = const Size(1080, 2340)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          ...deps.overrides(location: '/settings'),
          consentServiceProvider.overrideWithValue(consent),
          appVersionProvider.overrideWith((_) async => '1.0.0 (1)'),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BazaarSortApp(),
        ),
      );
      await settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings_consent')),
        200,
      );
      await tester.tap(find.byKey(const ValueKey('settings_consent')));
      await settle(tester, 3);
      expect(consent.optionsShown, 1);
      expect(deps.analytics.named('consent_result'), hasLength(1));
      expect(find.textContaining('1.0.0 (1)'), findsOneWidget);
    });

    testWidgets('language picker switches to Arabic (RTL)', (tester) async {
      final deps = TestDeps();
      final c = await pumpApp(tester, deps, location: '/settings');
      await tester.tap(find.byKey(const ValueKey('settings_language')));
      await settle(tester, 4);
      await tester.tap(find.byKey(const ValueKey('lang_ar')));
      await settle(tester, 4);
      expect(c.read(playerProvider).settings.localeCode, 'ar');
      expect(find.text('الإعدادات'), findsWidgets);
      final dir = Directionality.of(
        tester.element(find.byType(SettingsScreen)),
      );
      expect(dir, TextDirection.rtl);
    });
  });

  group('RTL and large text', () {
    for (final location in [
      '/home',
      '/play/12',
      '/shop',
      '/bazaar',
      '/daily',
    ]) {
      testWidgets('$location renders in Arabic without overflow', (
        tester,
      ) async {
        final deps = TestDeps(
          player: const PlayerState(
            settings: PlayerSettings(
              localeCode: 'ar',
              notificationsAsked: true,
            ),
          ),
        );
        await pumpApp(
          tester,
          deps,
          location: location,
          levels: {
            12: testLevel(const [
              [0, 0, 0, 1],
              [1, 1, 1, 0],
              [],
            ]),
          },
        );
        expect(tester.takeException(), isNull);
      });
    }

    for (final location in [
      '/home',
      '/play/12',
      '/shop',
      '/bazaar',
      '/daily',
      '/settings',
    ]) {
      testWidgets('$location handles 1.6× text scale', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final deps = TestDeps(
          player: const PlayerState(
            settings: PlayerSettings(notificationsAsked: true),
          ),
        );
        await pumpApp(
          tester,
          deps,
          location: location,
          levels: {
            12: testLevel(const [
              [0, 0, 0, 1],
              [1, 1, 1, 0],
              [],
            ]),
          },
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('every scaffolded locale is selectable in debug builds', () {
    expect(
      selectableLanguages(),
      containsAll(<String>['en', 'ur', 'ar', 'de', 'es', 'fr', 'id', 'tr']),
    );
    expect(languageName('ar'), 'العربية');
    expect(languageName('xx'), 'xx');
    expect(shippedLanguages, contains('en'));
  });

  test('picture cache reuses and evicts', () {
    final cache = PictureCache(capacity: 2);
    var draws = 0;
    void draw(Canvas c) => draws++;
    cache
      ..get('a', const Size(10, 10), draw)
      ..get('a', const Size(10, 10), draw)
      ..get('b', const Size(10, 10), draw)
      ..get('c', const Size(10, 10), draw);
    expect(draws, 3);
    expect(cache.hits, 1);
    expect(cache.length, 2);
    cache.get('a', const Size(10, 10), draw);
    expect(draws, 4, reason: 'a was evicted');
    cache.clear();
    expect(cache.length, 0);
  });
}
