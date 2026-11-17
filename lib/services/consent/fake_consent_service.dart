import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:bazaar_sort/services/consent/consent_service.dart';

/// Consent that resolves immediately with a configurable result.
class FakeConsentService implements ConsentService {
  /// Creates the fake.
  new({
    this.result = const ConsentResult(
      canRequestAds: true,
      personalization: AdPersonalization.nonPersonalized,
      privacyOptionsRequired: true,
    ),
  });

  /// Result returned by every call.
  ConsentResult result;

  /// How many times the privacy options form was opened.
  int optionsShown = 0;

  @override
  Future<ConsentResult> gatherConsent() async => result;

  @override
  Future<ConsentResult> showPrivacyOptions() async {
    optionsShown++;
    return result;
  }
}
