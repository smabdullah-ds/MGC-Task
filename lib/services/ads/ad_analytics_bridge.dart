import 'dart:async';

import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:bazaar_sort/services/ads/ads_service.dart';
import 'package:bazaar_sort/services/analytics/game_analytics.dart';

/// Forwards the ads SDK lifecycle to analytics, so fill rate and revenue per
/// placement can be read in Firebase (see KPI.md):
///
/// * `ad_request` — a network request was made;
/// * `ad_loaded` — it filled (fill rate = ad_loaded / ad_request);
/// * `ad_impression` — revenue from the paid-event callback;
/// * `ad_failed` — load or show failures with the error message.
///
/// `ad_reward_granted` is logged where the reward is applied, with the
/// gameplay placement.
class AdAnalyticsBridge {
  /// Starts forwarding [ads] events to [analytics].
  new(AdsService ads, this.analytics) {
    _sub = ads.events.listen(_onEvent);
  }

  /// Destination.
  final GameAnalytics analytics;
  late final StreamSubscription<AdEvent> _sub;

  void _onEvent(AdEvent e) {
    final format = e.format.name;
    switch (e.type) {
      case AdEventType.request:
        analytics.adRequest(format: format, placement: e.placement);
      case AdEventType.loaded:
        analytics.adLoaded(format: format);
      case AdEventType.impression:
        analytics.adImpression(
          format: format,
          placement: e.placement,
          network: e.network ?? 'unknown',
          valueMicros: e.valueMicros ?? 0,
          currency: e.currency ?? 'USD',
        );
      case AdEventType.failedToLoad || AdEventType.failedToShow:
        analytics.adFailed(
          format: format,
          placement: e.placement,
          error: e.errorMessage ?? e.type.name,
        );
      case AdEventType.rewardGranted || AdEventType.dismissed:
        break;
    }
  }

  /// Stops forwarding.
  Future<void> dispose() => _sub.cancel();
}
