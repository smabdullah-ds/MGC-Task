import 'package:bazaar_sort/services/ads/ads_service.dart';
import 'package:bazaar_sort/services/ads/fake_ads_service.dart';
import 'package:bazaar_sort/services/analytics/analytics_service.dart';
import 'package:bazaar_sort/services/analytics/fake_analytics_service.dart';
import 'package:bazaar_sort/services/consent/consent_service.dart';
import 'package:bazaar_sort/services/consent/fake_consent_service.dart';
import 'package:bazaar_sort/services/iap/fake_iap_service.dart';
import 'package:bazaar_sort/services/iap/iap_service.dart';
import 'package:bazaar_sort/services/notifications/fake_notification_service.dart';
import 'package:bazaar_sort/services/notifications/notification_service.dart';
import 'package:bazaar_sort/services/remote_config/fake_remote_config_service.dart';
import 'package:bazaar_sort/services/remote_config/remote_config_service.dart';
import 'package:bazaar_sort/services/storage/memory_storage_service.dart';
import 'package:bazaar_sort/services/storage/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Every external dependency is reached through one of these providers.
// They default to fakes so widget tests and offline builds need no setup;
// `bootstrap()` overrides them with real implementations at startup.

/// Ads.
final adsServiceProvider = Provider<AdsService>((ref) => FakeAdsService());

/// In-app purchases.
final iapServiceProvider = Provider<IapService>((ref) => FakeIapService());

/// Analytics + crash reporting.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => FakeAnalyticsService(),
);

/// Remote config.
final remoteConfigServiceProvider = Provider<RemoteConfigService>(
  (ref) => FakeRemoteConfigService(),
);

/// Persistent storage.
final storageServiceProvider = Provider<StorageService>(
  (ref) => MemoryStorageService(),
);

/// Local notifications.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => FakeNotificationService(),
);

/// UMP + ATT consent.
final consentServiceProvider = Provider<ConsentService>(
  (ref) => FakeConsentService(),
);
