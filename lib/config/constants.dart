/// Compile-time constants that are not tuning values.
///
/// Anything a designer might want to tweak lives in
/// `remote_config_defaults.dart` instead so it can be changed live.
abstract final class AppConstants {
  /// Display name of the game.
  static const String appName = 'Bazaar Sort';

  /// Number of levels bundled as JSON in `assets/levels/`.
  static const int bundledLevelCount = 1000;

  /// Levels per bundled JSON file.
  static const int levelsPerFile = 100;

  /// Minimum tap target in logical pixels (Material guideline).
  static const double minTapTarget = 48;

  /// Duration of an item's arc between shelves.
  static const Duration moveAnimation = Duration(milliseconds: 250);

  /// Hive box that holds the save game.
  static const String saveBoxName = 'bazaar_sort_save';
}
