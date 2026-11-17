import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:flutter/foundation.dart';

/// iOS App Tracking Transparency status (other platforms report
/// [TrackingStatus.notSupported]).
enum TrackingStatus {
  notDetermined,
  restricted,
  denied,
  authorized,
  notSupported,
}

/// Result of the consent flow.
@immutable
class ConsentResult {
  /// Creates a result.
  const new({
    required this.canRequestAds,
    required this.personalization,
    required this.privacyOptionsRequired,
    this.tracking = TrackingStatus.notSupported,
  });

  /// Whether any ad may be requested.
  final bool canRequestAds;

  /// Which kind of ads may be requested.
  final AdPersonalization personalization;

  /// Whether settings must show a "Manage consent" entry (UMP requirement).
  final bool privacyOptionsRequired;

  /// ATT outcome on iOS.
  final TrackingStatus tracking;

  /// Short label for the `consent_result` analytics event.
  String get label => '${personalization.name}_${tracking.name}';
}

/// Runs Google UMP (GDPR / US states) and the iOS ATT prompt.
abstract interface class ConsentService {
  /// Gathers consent: UMP form if required, then ATT on iOS. Never throws;
  /// on error it returns the most conservative result that still allows
  /// non-personalised ads where permitted.
  Future<ConsentResult> gatherConsent();

  /// Re-opens the UMP privacy options form ("Manage consent" in settings).
  Future<ConsentResult> showPrivacyOptions();
}
