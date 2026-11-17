/// Market tiers used for the `install_country_tier` user property (UA and
/// monetisation reporting).
abstract final class CountryTier {
  /// Primary revenue markets (the launch focus) plus similar high-ARPU
  /// countries.
  static const Set<String> tier1 = {
    'US', 'GB', 'CA', 'DE', 'AU', //
    'NZ', 'CH', 'NO', 'SE', 'DK', 'NL', 'AT', 'IE', 'FI', 'JP', 'KR',
  };

  /// Mid-value markets.
  static const Set<String> tier2 = {
    'FR',
    'IT',
    'ES',
    'BE',
    'IL',
    'SG',
    'HK',
    'TW',
    'AE',
    'SA',
    'QA',
    'KW',
    'PT',
    'PL',
    'CZ',
    'GR',
  };

  /// Tier label for an ISO 3166-1 alpha-2 [countryCode].
  static String of(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return 'unknown';
    final c = countryCode.toUpperCase();
    if (tier1.contains(c)) return 'tier1';
    if (tier2.contains(c)) return 'tier2';
    return 'tier3';
  }
}
