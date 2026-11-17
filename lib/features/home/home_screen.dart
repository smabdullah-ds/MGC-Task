import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/app/routes.dart';
import 'package:bazaar_sort/core/economy/bazaar_catalog.dart';
import 'package:bazaar_sort/core/economy/daily_progress.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';
import 'package:bazaar_sort/features/meta/bazaar_providers.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/features/splash/splash_screen.dart';
import 'package:bazaar_sort/shared/utils/l10n.dart';
import 'package:bazaar_sort/shared/widgets/bazaar_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Home: play button, coins, bazaar progress, daily, shop and settings.
class HomeScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final player = ref.watch(playerProvider);
    final catalog = ref.watch(bazaarCatalogProvider);
    final area = catalog.currentArea(player);
    final now = DateTime.now();
    const daily = DailyProgress();
    final dailyReady =
        daily.canClaimLogin(player, now) ||
        !daily.challengeDoneToday(player, now);

    return Scaffold(
      body: BazaarBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      key: const ValueKey('home_settings'),
                      tooltip: l10n.settings,
                      onPressed: () => context.push(Routes.settings),
                      icon: const Icon(Icons.settings_rounded),
                    ),
                    const Spacer(),
                    CoinPill(
                      coins: player.coins,
                      onTap: () => context.push(Routes.shop),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      key: const ValueKey('home_shop'),
                      tooltip: l10n.shop,
                      onPressed: () => context.push(Routes.shop),
                      icon: const Icon(Icons.storefront_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const BazaarLogo(size: 96),
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900, color: Palette.ink),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _AreaCard(
                  title: l10n.areaName(area.id),
                  progress: catalog.progress(player, area),
                  restored: catalog.restoredCount(player, area),
                  total: area.items.length,
                  onTap: () => context.push(Routes.bazaar),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 72,
                  child: FilledButton(
                    key: const ValueKey('home_play'),
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onPressed: () =>
                        context.go(Routes.playLevel(player.nextLevel)),
                    child: Text(l10n.playLevel(player.nextLevel)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _HomeTile(
                        key: const ValueKey('home_daily'),
                        icon: Icons.calendar_month_rounded,
                        label: l10n.daily,
                        badge: dailyReady,
                        onTap: () => context.push(Routes.daily),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HomeTile(
                        key: const ValueKey('home_bazaar'),
                        icon: Icons.mosque_rounded,
                        label: l10n.bazaar,
                        badge: _canRestoreSomething(
                          catalog,
                          player.coins,
                          player,
                        ),
                        onTap: () => context.push(Routes.bazaar),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canRestoreSomething(BazaarCatalog c, int coins, PlayerState player) {
    final next = c.nextItem(player);
    return next != null && coins >= c.costOf(next);
  }
}

class _AreaCard extends StatelessWidget {
  const new({
    required this.title,
    required this.progress,
    required this.restored,
    required this.total,
    required this.onTap,
  });

  final String title;
  final double progress;
  final int restored;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Palette.teal,
                child: Icon(Icons.mosque_rounded, color: Palette.ivory),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        color: Palette.saffron,
                        backgroundColor: Palette.sand,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(context.l10n.restoredOf(restored, total)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.badge,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.teal,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Stack(
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Palette.ivory, size: 28),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Palette.ivory,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (badge)
                const PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: CircleAvatar(
                    radius: 7,
                    backgroundColor: Palette.terracotta,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
