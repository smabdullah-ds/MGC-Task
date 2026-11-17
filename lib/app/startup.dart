import 'dart:async';

import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:bazaar_sort/services/consent/consent_service.dart';
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
      guard(
        'remote_config',
        () => _ref.read(remoteConfigServiceProvider).refresh(),
      ),
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
      guard('iap', () => _ref.read(iapServiceProvider).initialize()),
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
