import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:bazaar_sort/config/env.dart';
import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:bazaar_sort/services/ads/ads_service.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob (with mediation: AppLovin, Unity, Meta, Mintegral — adapters are
/// linked natively by the `gma_mediation_*` packages and configured in the
/// AdMob console).
///
/// * Preloads one rewarded, one interstitial and (if enabled) one app-open ad.
/// * Retries failed loads with exponential backoff (2 s → 64 s).
/// * Reports every lifecycle step, including the paid-event revenue, on
///   [events].
/// * Configured for a general 13+ audience: not child-directed, no age
///   restricted treatment, max content rating T.
class AdMobAdsService implements AdsService {
  /// Creates the service. [appOpenEnabled] comes from Remote Config.
  new({this.appOpenEnabled = false});

  /// Whether app-open ads are preloaded.
  final bool appOpenEnabled;

  final StreamController<AdEvent> _events =
      StreamController<AdEvent>.broadcast();

  AdPersonalization _personalization = AdPersonalization.none;
  bool _initialized = false;
  bool _nonRewardedDisabled = false;

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  AppOpenAd? _appOpen;
  final Map<AdFormat, int> _attempts = {};
  final Map<AdFormat, Timer> _retryTimers = {};

  String get _rewardedId =>
      Platform.isIOS ? Env.admobRewardedIos : Env.admobRewardedAndroid;
  String get _interstitialId =>
      Platform.isIOS ? Env.admobInterstitialIos : Env.admobInterstitialAndroid;
  String get _bannerId =>
      Platform.isIOS ? Env.admobBannerIos : Env.admobBannerAndroid;
  String get _appOpenId =>
      Platform.isIOS ? Env.admobAppOpenIos : Env.admobAppOpenAndroid;

  AdRequest get _request => AdRequest(
    nonPersonalizedAds: _personalization != AdPersonalization.personalized,
  );

  @override
  Stream<AdEvent> get events => _events.stream;

  @override
  Future<void> initialize({required AdPersonalization personalization}) async {
    _personalization = personalization;
    if (personalization == AdPersonalization.none) return;
    if (!_initialized) {
      // General audience 13+, not directed at children: no child or teen
      // age treatment (that would restrict ads for every player) and a
      // teen-appropriate content ceiling.
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          ageRestrictedTreatment: AgeRestrictedTreatment.unspecified,
          maxAdContentRating: MaxAdContentRating.t,
        ),
      );
      await MobileAds.instance.initialize();
      _initialized = true;
    }
    _loadRewarded();
    if (!_nonRewardedDisabled) {
      _loadInterstitial();
      if (appOpenEnabled) _loadAppOpen();
    }
  }

  // ---- Loading with backoff ------------------------------------------------

  void _scheduleRetry(AdFormat format, void Function() load) {
    final attempt = (_attempts[format] ?? 0) + 1;
    _attempts[format] = attempt;
    final seconds = math.min(64, math.pow(2, attempt).toInt());
    _retryTimers[format]?.cancel();
    _retryTimers[format] = Timer(Duration(seconds: seconds), load);
  }

  void _loaded(AdFormat format, String placement) {
    _attempts[format] = 0;
    _emit(AdEventType.loaded, format, placement);
  }

  void _failed(AdFormat format, String placement, Object error) {
    _emit(
      AdEventType.failedToLoad,
      format,
      placement,
      errorMessage: error.toString(),
    );
  }

  void _loadRewarded() {
    if (_rewarded != null || !_initialized) return;
    _emit(AdEventType.request, AdFormat.rewarded, 'preload');
    unawaited(
      RewardedAd.load(
        adUnitId: _rewardedId,
        request: _request,
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewarded = ad;
            _loaded(AdFormat.rewarded, 'preload');
          },
          onAdFailedToLoad: (e) {
            _failed(AdFormat.rewarded, 'preload', e.message);
            _scheduleRetry(AdFormat.rewarded, _loadRewarded);
          },
        ),
      ),
    );
  }

  void _loadInterstitial() {
    if (_interstitial != null || !_initialized || _nonRewardedDisabled) {
      return;
    }
    _emit(AdEventType.request, AdFormat.interstitial, 'preload');
    unawaited(
      InterstitialAd.load(
        adUnitId: _interstitialId,
        request: _request,
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitial = ad;
            _loaded(AdFormat.interstitial, 'preload');
          },
          onAdFailedToLoad: (e) {
            _failed(AdFormat.interstitial, 'preload', e.message);
            _scheduleRetry(AdFormat.interstitial, _loadInterstitial);
          },
        ),
      ),
    );
  }

  void _loadAppOpen() {
    if (_appOpen != null || !_initialized || _nonRewardedDisabled) return;
    unawaited(
      AppOpenAd.load(
        adUnitId: _appOpenId,
        request: _request,
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpen = ad;
            _loaded(AdFormat.appOpen, 'preload');
          },
          onAdFailedToLoad: (e) {
            _failed(AdFormat.appOpen, 'preload', e.message);
            _scheduleRetry(AdFormat.appOpen, _loadAppOpen);
          },
        ),
      ),
    );
  }

  // ---- Showing ---------------------------------------------------------------

  void _attachPaid(AdWithoutView ad, AdFormat format, String placement) {
    ad.onPaidEvent = _paidHandler(format, placement);
  }

  OnPaidEventCallback _paidHandler(AdFormat format, String placement) =>
      (ad, valueMicros, precision, currencyCode) => _emit(
        AdEventType.impression,
        format,
        placement,
        network: _network(ad),
        valueMicros: valueMicros.round(),
        currency: currencyCode,
      );

  static String _network(Ad ad) {
    final adapter =
        ad.responseInfo?.loadedAdapterResponseInfo?.adapterClassName ??
        ad.responseInfo?.mediationAdapterClassName ??
        'admob';
    final short = adapter.split('.').last;
    return short.isEmpty ? 'admob' : short;
  }

  @override
  bool get isRewardedReady => _rewarded != null;

  @override
  Future<bool> showRewarded(RewardedPlacement placement) async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    final done = Completer<bool>();
    var earned = false;
    _attachPaid(ad, AdFormat.rewarded, placement.name);
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        _emit(AdEventType.dismissed, AdFormat.rewarded, placement.name);
        if (!done.isCompleted) done.complete(earned);
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, e) {
        unawaited(ad.dispose());
        _emit(
          AdEventType.failedToShow,
          AdFormat.rewarded,
          placement.name,
          errorMessage: e.message,
        );
        if (!done.isCompleted) done.complete(false);
        _loadRewarded();
      },
    );
    await ad.show(
      onUserEarnedReward: (_, _) {
        earned = true;
        _emit(AdEventType.rewardGranted, AdFormat.rewarded, placement.name);
      },
    );
    return await done.future;
  }

  @override
  bool get isInterstitialReady =>
      _interstitial != null && !_nonRewardedDisabled;

  @override
  Future<bool> showInterstitial(String placement) async {
    final ad = _interstitial;
    if (ad == null || _nonRewardedDisabled) {
      _loadInterstitial();
      return false;
    }
    _interstitial = null;
    final done = Completer<bool>();
    _attachPaid(ad, AdFormat.interstitial, placement);
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        _emit(AdEventType.dismissed, AdFormat.interstitial, placement);
        if (!done.isCompleted) done.complete(true);
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, e) {
        unawaited(ad.dispose());
        _emit(
          AdEventType.failedToShow,
          AdFormat.interstitial,
          placement,
          errorMessage: e.message,
        );
        if (!done.isCompleted) done.complete(false);
        _loadInterstitial();
      },
    );
    await ad.show();
    return await done.future;
  }

  @override
  Future<bool> showAppOpen() async {
    final ad = _appOpen;
    if (ad == null || _nonRewardedDisabled) return false;
    _appOpen = null;
    final done = Completer<bool>();
    _attachPaid(ad, AdFormat.appOpen, 'app_open');
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        if (!done.isCompleted) done.complete(true);
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        unawaited(ad.dispose());
        if (!done.isCompleted) done.complete(false);
        _loadAppOpen();
      },
    );
    await ad.show();
    return await done.future;
  }

  @override
  Widget? buildBanner(String placement) {
    if (!_initialized || _nonRewardedDisabled) return null;
    return _AdMobBanner(
      adUnitId: _bannerId,
      request: _request,
      onPaid: _paidHandler(AdFormat.banner, placement),
    );
  }

  @override
  void disableNonRewarded() {
    _nonRewardedDisabled = true;
    unawaited(_interstitial?.dispose());
    unawaited(_appOpen?.dispose());
    _interstitial = null;
    _appOpen = null;
    _retryTimers.remove(AdFormat.interstitial)?.cancel();
    _retryTimers.remove(AdFormat.appOpen)?.cancel();
  }

  void _emit(
    AdEventType type,
    AdFormat format,
    String placement, {
    String? network,
    int? valueMicros,
    String? currency,
    String? errorMessage,
  }) {
    if (_events.isClosed) return;
    _events.add(
      AdEvent(
        type: type,
        format: format,
        placement: placement,
        network: network,
        valueMicros: valueMicros,
        currency: currency,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    for (final t in _retryTimers.values) {
      t.cancel();
    }
    await _rewarded?.dispose();
    await _interstitial?.dispose();
    await _appOpen?.dispose();
    await _events.close();
  }
}

class _AdMobBanner extends StatefulWidget {
  const new({
    required this.adUnitId,
    required this.request,
    required this.onPaid,
  });

  final String adUnitId;
  final AdRequest request;
  final OnPaidEventCallback onPaid;

  @override
  State<_AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<_AdMobBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: widget.request,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => unawaited(ad.dispose()),
        onPaidEvent: widget.onPaid,
      ),
    );
    _ad = ad;
    unawaited(ad.load());
  }

  @override
  void dispose() {
    unawaited(_ad?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
