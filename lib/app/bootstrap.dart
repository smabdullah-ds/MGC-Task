import 'dart:async';
import 'dart:io' show Platform;

import 'package:bazaar_sort/config/env.dart';
import 'package:bazaar_sort/config/remote_config_defaults.dart';
import 'package:bazaar_sort/services/ads/admob_ads_service.dart';
import 'package:bazaar_sort/services/ads/fake_ads_service.dart';
import 'package:bazaar_sort/services/analytics/analytics_service.dart';
import 'package:bazaar_sort/services/analytics/fake_analytics_service.dart';
import 'package:bazaar_sort/services/analytics/firebase_analytics_service.dart';
import 'package:bazaar_sort/services/audio/feedback_service.dart';
import 'package:bazaar_sort/services/consent/fake_consent_service.dart';
import 'package:bazaar_sort/services/consent/ump_consent_service.dart';
import 'package:bazaar_sort/services/iap/fake_iap_service.dart';
import 'package:bazaar_sort/services/iap/revenuecat_iap_service.dart';
import 'package:bazaar_sort/services/notifications/fake_notification_service.dart';
import 'package:bazaar_sort/services/notifications/local_notification_service.dart';
import 'package:bazaar_sort/services/remote_config/fake_remote_config_service.dart';
import 'package:bazaar_sort/services/remote_config/firebase_remote_config_service.dart';
import 'package:bazaar_sort/services/remote_config/remote_config_service.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:bazaar_sort/services/storage/hive_storage_service.dart';
import 'package:bazaar_sort/services/storage/memory_storage_service.dart';
import 'package:bazaar_sort/services/storage/storage_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
// Riverpod 3 exposes Override from the misc library.
import 'package:flutter_riverpod/misc.dart' show Override;

/// Creates the real services and returns provider overrides that swap them
/// in for the fakes. Each SDK is used only when it is configured:
///
/// | Service | Real when | Otherwise |
/// | --- | --- | --- |
/// | Analytics, Crashlytics, Remote Config | `FIREBASE_ENABLED=true` and Firebase initialises | in-memory fakes |
/// | Ads + UMP/ATT consent | `ADS_ENABLED` (default true) on Android/iOS | fakes (no ads) |
/// | In-app purchases | a RevenueCat key for this platform | fake store |
///
/// Only work needed before the first frame happens here (opening the save,
/// Firebase core, Remote Config defaults); slow work runs in `Startup`.
Future<List<Override>> bootstrap() async {
  final mobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  StorageService storage = HiveStorageService();
  try {
    await storage.initialize();
  } on Object catch (e) {
    debugPrint('storage init failed: $e');
    storage = MemoryStorageService();
  }

  AnalyticsService analytics = FakeAnalyticsService(printToConsole: kDebugMode);
  RemoteConfigService remoteConfig = FakeRemoteConfigService();
  if (Env.firebaseEnabled && mobile) {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      final firebaseAnalytics = FirebaseAnalyticsService()
        ..installErrorHandlers();
      await firebaseAnalytics.initialize();
      analytics = firebaseAnalytics;
      final rc = FirebaseRemoteConfigService();
      await rc.initialize().timeout(const Duration(seconds: 2));
      remoteConfig = rc;
    } on Object catch (e) {
      debugPrint('Firebase unavailable, using fakes: $e');
    }
  }

  final ads = Env.adsEnabled && mobile
      ? AdMobAdsService(
          appOpenEnabled: remoteConfig.getBool(RcKeys.appOpenEnabled),
        )
      : FakeAdsService();
  final consent = Env.adsEnabled && mobile
      ? UmpConsentService()
      : FakeConsentService();

  final rcKey = mobile
      ? RevenueCatIapService.keyForPlatform(
          android: Env.revenueCatAndroidKey,
          ios: Env.revenueCatIosKey,
        )
      : '';
  final iap = rcKey.isEmpty
      ? FakeIapService()
      : RevenueCatIapService(apiKey: rcKey);

  final notifications = mobile
      ? LocalNotificationService()
      : FakeNotificationService();

  final feedback = FlameFeedbackService();
  unawaited(feedback.initialize());

  return [
    storageServiceProvider.overrideWithValue(storage),
    analyticsServiceProvider.overrideWithValue(analytics),
    remoteConfigServiceProvider.overrideWithValue(remoteConfig),
    adsServiceProvider.overrideWithValue(ads),
    consentServiceProvider.overrideWithValue(consent),
    iapServiceProvider.overrideWithValue(iap),
    notificationServiceProvider.overrideWithValue(notifications),
    feedbackServiceProvider.overrideWithValue(feedback),
  ];
}
