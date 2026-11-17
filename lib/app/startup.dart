import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:bazaar_sort/config/remote_config_defaults.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/features/player/session_tasks.dart';
import 'package:bazaar_sort/features/shop/shop_controller.dart';
import 'package:bazaar_sort/services/ads/ad_analytics_bridge.dart';
import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:bazaar_sort/services/analytics/country_tier.dart';
import 'package:bazaar_sort/services/analytics/game_analytics.dart';
import 'package:bazaar_sort/services/consent/consent_service.dart';
import 'package:bazaar_sort/services/remote_config/tuning.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Startup sequence run by the splash screen:
/// 1. consent (UMP), then the iOS ATT prompt — before any ad request;
/// 2. ads, analytics, remote config, IAP and notifications in the
///    background (never blocking the first frame of play);
/// 3. apply the player's audio settings.
///
/// Every step is guarded: a failure (offline, SDK error) is recorded and the
/// game continues with ads/analytics simply unavailable.
class Startup {
  /// Creates the sequence.
  new(this._ref);

  final Ref _ref;

  /// Consent outcome, once known.
  ConsentResult? consent;

  /// Runs the sequence. Completes when the game can be shown.
  Future<void> run() async {
    final analytics = _ref.read(analyticsServiceProvider);
    final player = _ref.read(playerProvider);
    _ref
        .read(feedbackServiceProvider)
        .configure(
          sound: player.settings.sound,
          music: player.settings.music,
          haptics: player.settings.haptics,
        );

    try {
      consent = await _ref
          .read(consentServiceProvider)
          .gatherConsent()
          .timeout(const Duration(seconds: 12));
    } on Object catch (e, st) {
      unawaited(analytics.recordError(e, st, reason: 'consent'));
      consent = const ConsentResult(
        canRequestAds: false,
        personalization: AdPersonalization.none,
        privacyOptionsRequired: true,
      );
    }
    _ref.read(gameAnalyticsProvider).consentResult(result: consent!.label);

    // Ad lifecycle → analytics (fill, revenue, failures).
    final bridge = AdAnalyticsBridge(
      _ref.read(adsServiceProvider),
      _ref.read(gameAnalyticsProvider),
    );
    _ref.onDispose(() => unawaited(bridge.dispose()));

    final country = PlatformDispatcher.instance.locale.countryCode;
    _ref
        .read(gameAnalyticsProvider)
        .userProperty(UserProp.countryTier, CountryTier.of(country));

    // Background: never awaited by the splash.
    unawaited(_background(consent!));
  }

  Future<void> _background(ConsentResult consent) async {
    final analytics = _ref.read(analyticsServiceProvider);
    Future<void> guard(String name, Future<void> Function() step) async {
      try {
        await step();
      } on Object catch (e, st) {
        unawaited(analytics.recordError(e, st, reason: 'startup_$name'));
      }
    }

    await Future.wait([
      guard('remote_config', () async {
        final rc = _ref.read(remoteConfigServiceProvider);
        if (await rc.refresh()) {
          // Re-read tuning values everywhere.
          _ref
            ..invalidate(economyConfigProvider)
            ..invalidate(difficultyCurveProvider);
        }
        _ref
            .read(gameAnalyticsProvider)
            .userProperty(
              UserProp.experiment,
              rc.getString(RcKeys.experimentGroup),
            );
      }),
      guard(
        'ads',
        () => _ref
            .read(adsServiceProvider)
            .initialize(
              personalization: consent.canRequestAds
                  ? consent.personalization
                  : AdPersonalization.none,
            ),
      ),
      guard('iap', () async {
        await _ref.read(iapServiceProvider).initialize();
        _ref.read(shopControllerProvider).listenForUpdates();
        await _ref.read(sessionTasksProvider).onAppOpen();
      }),
      guard(
        'notifications',
        () => _ref.read(notificationServiceProvider).initialize(),
      ),
    ]);
  }
}

/// Runs once per app launch.
final startupProvider = FutureProvider<Startup>((ref) async {
  final s = Startup(ref);
  await s.run();
  return s;
});
