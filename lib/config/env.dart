/// Build-time configuration.
///
/// Values are injected with `--dart-define-from-file=.env.json` (the file is
/// git-ignored; copy `.env.example.json` to start). Every value has a safe
/// default so the app builds and runs with no secrets at all:
/// ad unit IDs fall back to Google's official **test** IDs and SDK keys fall
/// back to empty strings, which makes the service layer use its fakes.
abstract final class Env {
  /// `dev`, `staging` or `prod`.
  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  /// Whether this is a production build.
  static bool get isProd => flavor == 'prod';

  // ---- RevenueCat --------------------------------------------------------

  /// RevenueCat public SDK key for Google Play. Empty → fake IAP.
  static const String revenueCatAndroidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
  );

  /// RevenueCat public SDK key for the App Store. Empty → fake IAP.
  static const String revenueCatIosKey = String.fromEnvironment(
    'REVENUECAT_IOS_KEY',
  );

  // ---- Firebase ------------------------------------------------------------

  /// Set to `true` once `flutterfire configure` has been run and the native
  /// config files are in place. While `false` the app uses fake analytics,
  /// remote config and crash reporting.
  static const bool firebaseEnabled = bool.fromEnvironment('FIREBASE_ENABLED');

  // ---- AdMob ad units (defaults = Google test IDs) -----------------------

  /// Android rewarded ad unit.
  static const String admobRewardedAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );

  /// iOS rewarded ad unit.
  static const String admobRewardedIos = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  /// Android interstitial ad unit.
  static const String admobInterstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );

  /// iOS interstitial ad unit.
  static const String admobInterstitialIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );

  /// Android banner ad unit.
  static const String admobBannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );

  /// iOS banner ad unit.
  static const String admobBannerIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );

  /// Android app-open ad unit.
  static const String admobAppOpenAndroid = String.fromEnvironment(
    'ADMOB_APP_OPEN_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/9257395921',
  );

  /// iOS app-open ad unit.
  static const String admobAppOpenIos = String.fromEnvironment(
    'ADMOB_APP_OPEN_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/5575463023',
  );

  /// Whether the real AdMob SDK should be used. Off in tests and when
  /// explicitly disabled for offline QA builds.
  static const bool adsEnabled = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: true,
  );

  // ---- Links ---------------------------------------------------------------

  /// Public privacy policy URL (required by both stores).
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://example.com/bazaar-sort/privacy',
  );

  /// Support e-mail shown in settings.
  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@example.com',
  );
}
