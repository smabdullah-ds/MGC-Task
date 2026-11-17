import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/config/constants.dart';
import 'package:bazaar_sort/core/economy/booster.dart';
import 'package:bazaar_sort/shared/utils/l10n.dart';
import 'package:bazaar_sort/shared/widgets/bazaar_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// What a booster button shows in its corner badge.
sealed class BoosterBadge {
  const new();
}

/// Free or owned charges left.
final class CountBadge extends BoosterBadge {
  const new(this.count);
  final int count;
}

/// Needs payment: coins or a rewarded ad.
final class PayBadge extends BoosterBadge {
  const new();
}

/// Not available (e.g. extra shelf already used).
final class DisabledBadge extends BoosterBadge {
  const new();
}

/// One booster button's state.
final class BoosterButtonState {
  const new(this.type, this.badge, {this.highlighted = false});
  final BoosterType type;
  final BoosterBadge badge;
  final bool highlighted;
}

/// The bottom booster bar. Large, thumb-reachable buttons, kept well away
/// from any ad placement.
class BoosterBar extends StatelessWidget {
  const new({required this.buttons, required this.onPressed, super.key});

  final List<BoosterButtonState> buttons;
  final void Function(BoosterType) onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final b in buttons)
          _BoosterButton(state: b, onPressed: () => onPressed(b.type)),
      ],
    );
  }
}

class _BoosterButton extends StatelessWidget {
  const new({required this.state, required this.onPressed});

  final BoosterButtonState state;
  final VoidCallback onPressed;

  IconData get _icon => switch (state.type) {
    BoosterType.undo => Icons.undo_rounded,
    BoosterType.extraShelf => Icons.add_box_rounded,
    BoosterType.hint => Icons.lightbulb_rounded,
    BoosterType.shuffle => Icons.shuffle_rounded,
  };

  String _label(BuildContext context) => switch (state.type) {
    BoosterType.undo => context.l10n.boosterUndo,
    BoosterType.extraShelf => context.l10n.boosterExtraShelf,
    BoosterType.hint => context.l10n.boosterHint,
    BoosterType.shuffle => context.l10n.boosterShuffle,
  };

  @override
  Widget build(BuildContext context) {
    final disabled = state.badge is DisabledBadge;
    final label = _label(context);
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: InkWell(
          key: ValueKey('booster_${state.type.name}'),
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 72,
            height: 78,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Palette.teal,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: state.highlighted
                          ? Palette.saffron
                          : Palette.tealDeep,
                      width: state.highlighted ? 4 : 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(_icon, color: Palette.ivory, size: 30),
                ),
                Positioned(
                  bottom: 0,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Palette.ink,
                      fontSize: 13,
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: -4,
                  end: 0,
                  child: switch (state.badge) {
                    CountBadge(:final count) => _CountChip(count),
                    PayBadge() => const _PayChip(),
                    DisabledBadge() => const SizedBox.shrink(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const new(this.count);
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 22),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Palette.terracotta,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: Palette.ivory, width: 2),
    ),
    child: Text(
      '$count',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Palette.ivory,
        fontWeight: FontWeight.w900,
        fontSize: 12,
      ),
    ),
  );
}

class _PayChip extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Palette.ivory,
      shape: BoxShape.circle,
      border: Border.all(color: Palette.saffronDeep, width: 2),
    ),
    child: const Icon(Icons.add, size: 14, color: Palette.saffronDeep),
  );
}

/// Minimum tap target, re-exported for HUD widgets.
const double kTap = AppConstants.minTapTarget;

/// Coin + ad offer shown when a booster or continue must be paid for.
class OfferSheet extends StatelessWidget {
  const new({
    required this.title,
    required this.body,
    required this.icon,
    required this.coinPrice,
    required this.canAfford,
    required this.adAvailable,
    this.ownedCount = 0,
    super.key,
  });

  final String title;
  final String body;
  final IconData icon;
  final int coinPrice;
  final bool canAfford;
  final bool adAvailable;
  final int ownedCount;

  /// Shows the sheet; completes with the chosen source name
  /// (`inventory`, `coins`, `ad`) or `null` when dismissed.
  static Future<String?> show(BuildContext context, OfferSheet sheet) =>
      showModalBottomSheet<String>(
        context: context,
        backgroundColor: Palette.ivory,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => sheet,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Palette.teal,
              child: Icon(icon, size: 34, color: Palette.ivory),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (ownedCount > 0) ...[
              FilledButton(
                key: const ValueKey('offer_inventory'),
                onPressed: () => Navigator.pop(context, 'inventory'),
                child: Text(l10n.useOwned(ownedCount)),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('offer_ad'),
                    onPressed: adAvailable
                        ? () => Navigator.pop(context, 'ad')
                        : null,
                    icon: const AdBadge(),
                    label: Text(l10n.watchAd),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('offer_coins'),
                    onPressed: canAfford
                        ? () => Navigator.pop(context, 'coins')
                        : null,
                    icon: const CoinIcon(size: 18),
                    label: Text('$coinPrice'),
                  ),
                ),
              ],
            ),
            if (!canAfford) ...[
              const SizedBox(height: 8),
              Text(
                l10n.notEnoughCoins,
                style: const TextStyle(color: Palette.terracotta),
              ),
            ],
            if (!adAvailable) ...[
              const SizedBox(height: 8),
              Text(l10n.adUnavailable, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
