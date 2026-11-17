import 'dart:async';

import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/app/routes.dart';
import 'package:bazaar_sort/config/remote_config_defaults.dart';
import 'package:bazaar_sort/core/economy/bazaar_catalog.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';
import 'package:bazaar_sort/features/meta/bazaar_providers.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/services/audio/feedback_service.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:bazaar_sort/shared/utils/l10n.dart';
import 'package:bazaar_sort/shared/widgets/bazaar_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Area colours and item icons (placeholder art; swap for illustrations).
const Map<String, Color> _areaColors = {
  'spice_market': Palette.saffronDeep,
  'lantern_street': Palette.teal,
  'tea_house': Palette.terracotta,
  'textile_lane': Palette.plum,
};

const Map<String, IconData> _itemIcons = {
  'spice_awning': Icons.storefront_rounded,
  'spice_sacks': Icons.shopping_bag_rounded,
  'spice_scales': Icons.balance_rounded,
  'spice_counter': Icons.table_bar_rounded,
  'spice_lamps': Icons.light_rounded,
  'spice_sign': Icons.signpost_rounded,
  'lantern_arch': Icons.architecture_rounded,
  'lantern_strings': Icons.festival_rounded,
  'lantern_stall': Icons.lightbulb_rounded,
  'lantern_fountain': Icons.water_drop_rounded,
  'lantern_benches': Icons.chair_rounded,
  'lantern_tower': Icons.watch_later_rounded,
  'lantern_gate': Icons.door_front_door_rounded,
  'tea_carpets': Icons.texture_rounded,
  'tea_samovar': Icons.coffee_maker_rounded,
  'tea_cushions': Icons.weekend_rounded,
  'tea_tables': Icons.table_restaurant_rounded,
  'tea_windows': Icons.window_rounded,
  'tea_dome': Icons.mosque_rounded,
  'tea_garden': Icons.local_florist_rounded,
  'textile_looms': Icons.grid_on_rounded,
  'textile_dyes': Icons.palette_rounded,
  'textile_racks': Icons.dry_cleaning_rounded,
  'textile_awnings': Icons.roofing_rounded,
  'textile_carts': Icons.shopping_cart_rounded,
  'textile_well': Icons.water_rounded,
  'textile_minaret': Icons.account_balance_rounded,
  'textile_gate': Icons.fort_rounded,
};

/// Scrollable map of bazaar areas. Tap an item to restore it for coins.
class BazaarScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<BazaarScreen> createState() => _BazaarScreenState();
}

class _BazaarScreenState extends ConsumerState<BazaarScreen> {
  String? _justRestored;

  Future<void> _restore(BazaarItem item) async {
    final catalog = ref.read(bazaarCatalogProvider);
    final store = ref.read(playerProvider.notifier);
    final result = catalog.restore(store.current, item.id);
    final l10n = context.l10n;
    if (result == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.notEnoughCoins),
            action: SnackBarAction(
              label: l10n.shop,
              onPressed: () => context.push(Routes.shop),
            ),
          ),
        );
      return;
    }
    await store.update((_) => result.state);
    final analytics = ref.read(gameAnalyticsProvider);
    final area = BazaarCatalog.areaOf(item.id);
    analytics
      ..bazaarItemRestored(item: item.id, area: area.id, cost: result.cost)
      ..coinsSpent(amount: result.cost, sink: 'bazaar');
    ref.read(feedbackServiceProvider)
      ..play(Sfx.restore)
      ..haptic(Haptic.medium);
    if (!mounted) return;
    setState(() => _justRestored = item.id);

    final completed = result.completedArea;
    if (completed != null) {
      analytics
        ..areaComplete(
          area: completed.id,
          levelsPlayed: result.state.levelsCompleted,
        )
        ..coinsEarned(amount: completed.rewardCoins, source: 'area_complete');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const ValueKey('area_complete_dialog'),
          icon: const Icon(
            Icons.celebration_rounded,
            color: Palette.saffron,
            size: 48,
          ),
          title: Text(l10n.areaCompleteTitle(l10n.areaName(completed.id))),
          content: Text(l10n.areaCompleteBody(completed.rewardCoins)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.continueLabel),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final player = ref.watch(playerProvider);
    final catalog = ref.watch(bazaarCatalogProvider);
    final rc = ref.watch(remoteConfigServiceProvider);
    final adFree =
        player.purchases.removeAds ||
        player.purchases.vipActiveAt(DateTime.now());
    final banner = rc.getBool(RcKeys.bannerBazaarEnabled) && !adFree
        ? ref.read(adsServiceProvider).buildBanner('bazaar')
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bazaar),
        actions: [
          CoinPill(coins: player.coins, onTap: () => context.push(Routes.shop)),
          const SizedBox(width: 8),
        ],
      ),
      body: BazaarBackground(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  for (final area in BazaarCatalog.areas)
                    _AreaSection(
                      area: area,
                      player: player,
                      catalog: catalog,
                      justRestored: _justRestored,
                      onRestore: (item) => unawaited(_restore(item)),
                    ),
                ],
              ),
            ),
            // Banner experiment (Remote Config, off by default). Kept in its
            // own strip, separated from every tap target.
            if (banner != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: banner,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AreaSection extends StatelessWidget {
  const new({
    required this.area,
    required this.player,
    required this.catalog,
    required this.justRestored,
    required this.onRestore,
  });

  final BazaarArea area;
  final PlayerState player;
  final BazaarCatalog catalog;
  final String? justRestored;
  final void Function(BazaarItem) onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unlocked = catalog.isUnlocked(player, area);
    final color = _areaColors[area.id] ?? Palette.teal;
    final index = BazaarCatalog.areas.indexOf(area);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: unlocked ? color : Colors.grey.shade600,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  unlocked ? Icons.mosque_rounded : Icons.lock_rounded,
                  color: Palette.ivory,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.areaName(area.id),
                        style: const TextStyle(
                          color: Palette.ivory,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (unlocked)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: catalog.progress(player, area),
                            minHeight: 8,
                            color: Palette.ivory,
                            backgroundColor: Palette.ivory.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        )
                      else
                        Text(
                          l10n.areaLockedHint(
                            l10n.areaName(BazaarCatalog.areas[index - 1].id),
                          ),
                          style: const TextStyle(color: Palette.ivory),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TwoColumnGrid(
            spacing: 10,
            children: [
              for (final item in area.items)
                _ItemTile(
                  item: item,
                  color: color,
                  cost: catalog.costOf(item),
                  restored: player.restoredItems.contains(item.id),
                  unlocked: unlocked,
                  affordable: player.coins >= catalog.costOf(item),
                  celebrate: justRestored == item.id,
                  onRestore: () => onRestore(item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const new({
    required this.item,
    required this.color,
    required this.cost,
    required this.restored,
    required this.unlocked,
    required this.affordable,
    required this.celebrate,
    required this.onRestore,
  });

  final BazaarItem item;
  final Color color;
  final int cost;
  final bool restored;
  final bool unlocked;
  final bool affordable;
  final bool celebrate;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final icon = _itemIcons[item.id] ?? Icons.storefront_rounded;
    final art = TweenAnimationBuilder<double>(
      key: ValueKey('${item.id}_$restored'),
      tween: Tween(begin: celebrate ? 0.4 : 1, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: CircleAvatar(
        radius: 34,
        backgroundColor: restored ? color : Colors.grey.shade400,
        child: Icon(
          icon,
          size: 36,
          color: restored ? Palette.ivory : Colors.grey.shade700,
        ),
      ),
    );
    return Card(
      key: ValueKey('bazaar_${item.id}'),
      color: restored ? Colors.white : const Color(0xFFF3EDE2),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            art,
            const SizedBox(height: 6),
            Text(
              l10n.itemName(item.id),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            if (restored)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Palette.teal),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(l10n.restored, overflow: TextOverflow.ellipsis),
                  ),
                ],
              )
            else if (!unlocked)
              Text(l10n.locked)
            else
              FilledButton.icon(
                key: ValueKey('restore_${item.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: affordable ? color : Colors.grey.shade500,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: onRestore,
                icon: const CoinIcon(size: 16),
                label: Text('$cost'),
              ),
          ],
        ),
      ),
    );
  }
}
