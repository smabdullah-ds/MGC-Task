import 'package:bazaar_sort/app/routes.dart';
import 'package:bazaar_sort/shared/widgets/placeholder_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// App router.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, _) => const PlaceholderScreen(title: 'Bazaar Sort'),
      ),
      GoRoute(
        path: Routes.home,
        builder: (_, _) => const PlaceholderScreen(title: 'Home'),
      ),
      GoRoute(
        path: Routes.bazaar,
        builder: (_, _) => const PlaceholderScreen(title: 'Bazaar'),
      ),
      GoRoute(
        path: Routes.shop,
        builder: (_, _) => const PlaceholderScreen(title: 'Shop'),
      ),
      GoRoute(
        path: Routes.daily,
        builder: (_, _) => const PlaceholderScreen(title: 'Daily'),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const PlaceholderScreen(title: 'Settings'),
      ),
    ],
  );
});
