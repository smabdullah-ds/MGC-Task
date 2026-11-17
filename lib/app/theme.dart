import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/config/constants.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the app theme. Text uses the platform's scalable sizes so Dynamic
/// Type / font scaling applies to all menu text.
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.teal,
    primary: Palette.teal,
    secondary: Palette.saffron,
    tertiary: Palette.terracotta,
    surface: Palette.ivory,
  );
  const minSize = Size(AppConstants.minTapTarget, AppConstants.minTapTarget);
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.ivory,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Palette.ink,
      elevation: 0,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minSize,
        shape: rounded,
        backgroundColor: Palette.terracotta,
        foregroundColor: Palette.ivory,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minSize,
        shape: rounded,
        foregroundColor: Palette.ink,
        side: const BorderSide(color: Palette.wood, width: 2),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: minSize),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.ivory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
