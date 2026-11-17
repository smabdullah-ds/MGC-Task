import 'package:bazaar_sort/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Languages with complete, reviewed translations. Only these are offered
/// to players in release builds; the other scaffolded locales are visible in
/// debug builds (and with `--dart-define=ALL_LOCALES=true`) for QA, RTL
/// checks and translators.
const Set<String> shippedLanguages = {'en'};

const bool _allLocales = bool.fromEnvironment('ALL_LOCALES');

/// Locales the app declares to Flutter.
List<Locale> get appSupportedLocales => kDebugMode || _allLocales
    ? AppLocalizations.supportedLocales
    : [
        for (final l in AppLocalizations.supportedLocales)
          if (shippedLanguages.contains(l.languageCode)) l,
      ];

/// Language codes shown in the settings picker.
List<String> selectableLanguages() => [
  for (final l in appSupportedLocales) l.languageCode,
];

/// Endonym for a language code.
String languageName(String code) => switch (code) {
  'en' => 'English',
  'ur' => 'اردو',
  'ar' => 'العربية',
  'de' => 'Deutsch',
  'es' => 'Español',
  'fr' => 'Français',
  'id' => 'Bahasa Indonesia',
  'tr' => 'Türkçe',
  _ => code,
};
