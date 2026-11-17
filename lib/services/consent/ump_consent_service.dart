import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart'
    as att;
import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:bazaar_sort/services/consent/consent_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google UMP (GDPR + US state privacy) followed by the iOS ATT prompt.
///
/// Order matters: UMP first (it may show the consent form), then ATT, and
/// only then are ads initialised — so no ad is requested before consent.
class UmpConsentService implements ConsentService {
  @override
  Future<ConsentResult> gatherConsent() async {
    await _updateConsentInfo();
    await _showFormIfRequired();
    final tracking = await _requestTracking();
    return await _result(tracking);
  }

  @override
  Future<ConsentResult> showPrivacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((_) => done.complete());
    await done.future;
    return await _result(await _trackingStatus());
  }

  Future<void> _updateConsentInfo() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      // The game is for a general 13+ audience, so players are not treated
      // as under the age of consent.
      ConsentRequestParameters(tagForUnderAgeOfConsent: false),
      done.complete,
      (error) => done.completeError(StateError(error.message)),
    );
    return done.future;
  }

  Future<void> _showFormIfRequired() {
    final done = Completer<void>();
    unawaited(
      ConsentForm.loadAndShowConsentFormIfRequired((_) => done.complete()),
    );
    return done.future;
  }

  Future<TrackingStatus> _requestTracking() async {
    if (!Platform.isIOS) return TrackingStatus.notSupported;
    final status =
        await att.AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == att.TrackingStatus.notDetermined) {
      // Apple recommends a short delay after the app becomes active.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return _map(
        await att.AppTrackingTransparency.requestTrackingAuthorization(),
      );
    }
    return _map(status);
  }

  Future<TrackingStatus> _trackingStatus() async => Platform.isIOS
      ? _map(await att.AppTrackingTransparency.trackingAuthorizationStatus)
      : TrackingStatus.notSupported;

  static TrackingStatus _map(att.TrackingStatus s) => switch (s) {
    att.TrackingStatus.notDetermined => TrackingStatus.notDetermined,
    att.TrackingStatus.restricted => TrackingStatus.restricted,
    att.TrackingStatus.denied => TrackingStatus.denied,
    att.TrackingStatus.authorized => TrackingStatus.authorized,
    att.TrackingStatus.notSupported => TrackingStatus.notSupported,
  };

  Future<ConsentResult> _result(TrackingStatus tracking) async {
    final info = ConsentInformation.instance;
    final canRequest = await info.canRequestAds();
    final status = await info.getConsentStatus();
    final options = await info.getPrivacyOptionsRequirementStatus();
    // Personalised only when UMP allows ads and (on iOS) ATT was granted.
    // UMP's own per-vendor choices are enforced by the SDK itself.
    final iosDenied = Platform.isIOS && tracking != TrackingStatus.authorized;
    final personalization = !canRequest
        ? AdPersonalization.none
        : iosDenied
        ? AdPersonalization.nonPersonalized
        : status == ConsentStatus.obtained ||
              status == ConsentStatus.notRequired
        ? AdPersonalization.personalized
        : AdPersonalization.nonPersonalized;
    return ConsentResult(
      canRequestAds: canRequest,
      personalization: personalization,
      privacyOptionsRequired:
          options == PrivacyOptionsRequirementStatus.required,
      tracking: tracking,
    );
  }
}
