import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:flutter/widgets.dart';

/// Loads and shows ads. Implementations preload, retry with backoff and
/// report every lifecycle step on [events].
///
/// Policy decisions (whether an interstitial *should* show) live in
/// `InterstitialPolicy`; this service only executes.
abstract interface class AdsService {
  /// Initialises the SDK after consent. [personalization] decides whether
  /// personalised ads may be requested; [AdPersonalization.none] disables
  /// ad requests entirely.
  Future<void> initialize({required AdPersonalization personalization});

  /// Ad lifecycle stream for analytics.
  Stream<AdEvent> get events;

  /// Whether a rewarded ad is loaded and can be shown now.
  bool get isRewardedReady;

  /// Shows a rewarded ad. Completes with `true` only if the user earned the
  /// reward. Never throws; offline or no-fill returns `false`.
  Future<bool> showRewarded(RewardedPlacement placement);

  /// Whether an interstitial is loaded.
  bool get isInterstitialReady;

  /// Shows an interstitial. Completes when it is dismissed (or immediately
  /// with `false` if none was ready).
  Future<bool> showInterstitial(String placement);

  /// Builds a banner widget for [placement], or `null` if banners are not
  /// available. Callers decide *whether* to show it.
  Widget? buildBanner(String placement);

  /// Shows an app-open ad if one is loaded.
  Future<bool> showAppOpen();

  /// Stops all ads permanently for this session (e.g. after `remove_ads`).
  /// Rewarded ads stay available because they are user-initiated.
  void disableNonRewarded();

  /// Releases resources.
  Future<void> dispose();
}
