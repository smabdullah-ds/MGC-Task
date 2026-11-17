import 'dart:async';

import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:bazaar_sort/services/ads/ads_service.dart';
import 'package:flutter/widgets.dart';

/// Ads that always "fill" instantly. Used in tests, offline QA and when the
/// ads SDK is disabled.
class FakeAdsService implements AdsService {
  /// Creates the fake. Set [fill] to `false` to simulate no-fill.
  new({this.fill = true, this.rewardDelay = Duration.zero});

  /// Whether ads are available.
  bool fill;

  /// Simulated ad duration.
  final Duration rewardDelay;

  final StreamController<AdEvent> _events =
      StreamController<AdEvent>.broadcast();

  /// Placements of rewarded ads shown so far.
  final List<RewardedPlacement> rewardedShown = <RewardedPlacement>[];

  /// Placements of interstitials shown so far.
  final List<String> interstitialsShown = <String>[];

  /// Personalisation passed to [initialize].
  AdPersonalization? personalization;

  bool _nonRewardedDisabled = false;

  @override
  Stream<AdEvent> get events => _events.stream;

  @override
  Future<void> initialize({required AdPersonalization personalization}) async {
    this.personalization = personalization;
  }

  bool get _canServe => fill && personalization != AdPersonalization.none;

  @override
  bool get isRewardedReady => _canServe;

  @override
  bool get isInterstitialReady => _canServe && !_nonRewardedDisabled;

  @override
  Future<bool> showRewarded(RewardedPlacement placement) async {
    if (!isRewardedReady) return false;
    if (rewardDelay > Duration.zero) await Future<void>.delayed(rewardDelay);
    rewardedShown.add(placement);
    _emit(AdEventType.impression, AdFormat.rewarded, placement.name);
    _emit(AdEventType.rewardGranted, AdFormat.rewarded, placement.name);
    return true;
  }

  @override
  Future<bool> showInterstitial(String placement) async {
    if (!isInterstitialReady) return false;
    interstitialsShown.add(placement);
    _emit(AdEventType.impression, AdFormat.interstitial, placement);
    return true;
  }

  @override
  Widget? buildBanner(String placement) => null;

  @override
  Future<bool> showAppOpen() async => false;

  @override
  void disableNonRewarded() => _nonRewardedDisabled = true;

  void _emit(AdEventType type, AdFormat format, String placement) {
    _events.add(
      AdEvent(
        type: type,
        format: format,
        placement: placement,
        network: 'fake',
        valueMicros: 0,
        currency: 'USD',
      ),
    );
  }

  @override
  Future<void> dispose() => _events.close();
}
