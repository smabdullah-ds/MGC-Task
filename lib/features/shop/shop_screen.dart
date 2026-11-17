import 'dart:async';

import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/core/economy/purchase_granter.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/features/shop/shop_controller.dart';
import 'package:bazaar_sort/services/iap/iap_types.dart';
import 'package:bazaar_sort/services/remote_config/tuning.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:bazaar_sort/shared/utils/l10n.dart';
import 'package:bazaar_sort/shared/widgets/bazaar_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The store: starter pack, remove ads, VIP, coin packs, booster bundle and
/// restore purchases. Prices always come from the store (localized).
class ShopScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  Map<String, StoreProduct> _products = const {};
  bool _loading = true;
  String? _buying;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    ref.read(gameAnalyticsProvider).iapView(placement: 'shop');
    unawaited(_load());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await ref.read(shopControllerProvider).products();
    if (!mounted) return;
    setState(() {
      _products = {for (final p in list) p.id: p};
      _loading = false;
    });
  }

  Future<void> _buy(String id) async {
    setState(() => _buying = id);
    final outcome = await ref.read(shopControllerProvider).buy(id);
    if (!mounted) return;
    setState(() => _buying = null);
    final l10n = context.l10n;
    final msg = switch (outcome) {
      ShopOutcome.granted => l10n.purchaseThanks,
      ShopOutcome.pending => l10n.purchasePending,
      ShopOutcome.failed => l10n.purchaseFailed,
      ShopOutcome.cancelled || ShopOutcome.duplicate => null,
    };
    if (msg != null) _toast(msg);
  }

  Future<void> _restore() async {
    final n = await ref.read(shopControllerProvider).restore();
    if (!mounted) return;
    _toast(
      n > 0
          ? context.l10n.purchaseRestored
          : context.l10n.purchaseNothingToRestore,
    );
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final player = ref.watch(playerProvider);
    final cfg = ref.watch(economyConfigProvider);
    final now = DateTime.now();
    final starterLeft = const PurchaseGranter().starterOfferRemaining(
      player,
      now,
      hours: cfg.starterPackHours,
    );
    final p = player.purchases;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shopTitle),
        actions: [
          CoinPill(coins: player.coins),
          const SizedBox(width: 8),
        ],
      ),
      body: BazaarBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_products.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.offline, textAlign: TextAlign.center),
              ),
            if (starterLeft != null)
              _OfferCard(
                key: const ValueKey('shop_starter_pack'),
                color: Palette.terracotta,
                icon: Icons.card_giftcard_rounded,
                title: l10n.starterPackTitle,
                body: l10n.starterPackBody,
                footer: l10n.starterPackEnds(_format(starterLeft)),
                product: _products[Products.starterPack.id],
                busy: _buying == Products.starterPack.id,
                onBuy: () => _buy(Products.starterPack.id),
              ),
            _OfferCard(
              key: const ValueKey('shop_remove_ads'),
              color: Palette.teal,
              icon: Icons.block_rounded,
              title: l10n.removeAdsTitle,
              body: l10n.removeAdsBody,
              product: _products[Products.removeAds.id],
              owned: p.removeAds,
              busy: _buying == Products.removeAds.id,
              onBuy: () => _buy(Products.removeAds.id),
            ),
            _OfferCard(
              key: const ValueKey('shop_vip'),
              color: Palette.plum,
              icon: Icons.workspace_premium_rounded,
              title: l10n.vipTitle,
              body: l10n.vipBody,
              product: _products[Products.vipWeekly.id],
              priceFormatter: l10n.vipPerWeek,
              owned: p.vipActiveAt(now),
              ownedLabel: l10n.vipActive,
              busy: _buying == Products.vipWeekly.id,
              onBuy: () => _buy(Products.vipWeekly.id),
            ),
            const SizedBox(height: 8),
            TwoColumnGrid(
              children: [
                for (final (product, tag) in [
                  (Products.coinsS, null),
                  (Products.coinsM, l10n.popular),
                  (Products.coinsL, null),
                  (Products.coinsXl, l10n.bestValue),
                ])
                  _CoinPackTile(
                    key: ValueKey('shop_${product.id}'),
                    coins: product.coins,
                    tag: tag,
                    product: _products[product.id],
                    busy: _buying == product.id,
                    onBuy: () => _buy(product.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _OfferCard(
              key: const ValueKey('shop_booster_bundle'),
              color: Palette.saffronDeep,
              icon: Icons.auto_awesome_rounded,
              title: l10n.boosterBundleTitle,
              body: l10n.boosterBundleBody,
              product: _products[Products.boosterBundle.id],
              busy: _buying == Products.boosterBundle.id,
              onBuy: () => _buy(Products.boosterBundle.id),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                key: const ValueKey('shop_restore'),
                onPressed: _restore,
                child: Text(l10n.restorePurchases),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _format(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
}

class _OfferCard extends StatelessWidget {
  const new({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
    required this.product,
    required this.busy,
    required this.onBuy,
    this.footer,
    this.owned = false,
    this.ownedLabel,
    this.priceFormatter,
    super.key,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;
  final String? footer;
  final StoreProduct? product;
  final bool busy;
  final bool owned;
  final String? ownedLabel;
  final String Function(String)? priceFormatter;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final price = product?.priceString;
    final action = owned
        ? Chip(label: Text(ownedLabel ?? context.l10n.owned))
        : FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: price == null || busy ? null : onBuy,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    price == null ? '—' : priceFormatter?.call(price) ?? price,
                  ),
          );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color,
              child: Icon(icon, color: Palette.ivory, size: 30),
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
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(body),
                  if (footer != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      footer!,
                      style: const TextStyle(
                        color: Palette.terracotta,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: action,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinPackTile extends StatelessWidget {
  const new({
    required this.coins,
    required this.product,
    required this.busy,
    required this.onBuy,
    this.tag,
    super.key,
  });

  final int coins;
  final String? tag;
  final StoreProduct? product;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final price = product?.priceString;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: price == null || busy ? null : onBuy,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinIcon(size: 44),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.coinPack(coins),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: price == null || busy ? null : onBuy,
                    child: Text(price ?? '—'),
                  ),
                ],
              ),
            ),
            if (tag != null)
              PositionedDirectional(
                top: 0,
                end: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: const BoxDecoration(
                    color: Palette.terracotta,
                    borderRadius: BorderRadiusDirectional.only(
                      bottomStart: Radius.circular(10),
                    ),
                  ),
                  child: Text(
                    tag!,
                    style: const TextStyle(
                      color: Palette.ivory,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
