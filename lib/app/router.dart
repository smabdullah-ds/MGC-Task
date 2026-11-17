import 'package:bazaar_sort/app/routes.dart';
import 'package:bazaar_sort/features/daily/daily_screen.dart';
import 'package:bazaar_sort/features/gameplay/screens/gameplay_screen.dart';
import 'package:bazaar_sort/features/home/home_screen.dart';
import 'package:bazaar_sort/features/meta/bazaar_screen.dart';
import 'package:bazaar_sort/features/screenshots/screenshot_scenes.dart';
import 'package:bazaar_sort/features/settings/settings_screen.dart';
import 'package:bazaar_sort/features/shop/shop_screen.dart';
import 'package:bazaar_sort/features/splash/splash_screen.dart';
import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Builds the app router. [initialLocation] is overridable for tests and the
/// screenshot route.
GoRouter buildRouter({String initialLocation = Routes.splash}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: '${Routes.play}/:level',
      builder: (_, state) {
        final level = int.tryParse(state.pathParameters['level'] ?? '') ?? 1;
        // A fresh key per level so "Continue" builds a new game.
        return GameplayScreen(
          key: ValueKey('level_$level'),
          level: level < 1 ? 1 : level,
        );
      },
    ),
    GoRoute(path: Routes.daily, builder: (_, _) => const DailyScreen()),
    GoRoute(
      path: Routes.dailyChallenge,
      builder: (_, _) => const GameplayScreen(level: 0, daily: true),
    ),
    GoRoute(path: Routes.bazaar, builder: (_, _) => const BazaarScreen()),
    GoRoute(path: Routes.shop, builder: (_, _) => const ShopScreen()),
    GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
    if (screenshotsEnabled)
      GoRoute(
        path: Routes.screenshots,
        builder: (_, _) => const ScreenshotScenesScreen(),
      ),
  ],
);

/// App router.
final routerProvider = Provider<GoRouter>((ref) => buildRouter());
