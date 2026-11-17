import 'package:bazaar_sort/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// Shorthand for localized strings: `context.l10n.appTitle`.
extension L10nContext on BuildContext {
  /// Localized strings for this context.
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Strings for tutorial step ids (`tut_<id>` keys).
extension TutorialStrings on AppLocalizations {
  /// Coach text for a tutorial step id.
  String tutorial(String id) => switch (id) {
    'pick' => tut_pick,
    'match' => tut_match,
    'empty' => tut_empty,
    'undo' => tut_undo,
    'stars' => tut_stars,
    'hint' => tut_hint,
    'partial' => tut_partial,
    'extra_shelf' => tut_extra_shelf,
    'shuffle' => tut_shuffle,
    'boss' => tut_boss,
    'hidden' => tut_hidden,
    'locked' => tut_locked,
    'frozen' => tut_frozen,
    'move_limit' => tut_move_limit,
    _ => '',
  };
}
