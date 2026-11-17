import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/core/game_logic/game_session.dart';
import 'package:bazaar_sort/shared/utils/l10n.dart';
import 'package:bazaar_sort/shared/widgets/bazaar_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Win panel: stars, coins, optional 2× coins via rewarded ad, Continue.
///
/// The win (progress + coins) is already saved before this is shown, so
/// killing the app here never loses anything.
class WinPanel extends StatefulWidget {
  const new({
    required this.stars,
    required this.coins,
    required this.moves,
    required this.targetMoves,
    required this.boss,
    required this.canDouble,
    required this.onDouble,
    required this.onContinue,
    super.key,
  });

  final int stars;
  final int coins;
  final int moves;
  final int targetMoves;
  final bool boss;
  final bool canDouble;
  final Future<bool> Function() onDouble;
  final VoidCallback onContinue;

  @override
  State<WinPanel> createState() => _WinPanelState();
}

class _WinPanelState extends State<WinPanel> {
  late int _coins = widget.coins;
  bool _doubled = false;
  bool _busy = false;

  Future<void> _double() async {
    setState(() => _busy = true);
    final ok = await widget.onDouble();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _doubled = true;
        _coins *= 2;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Panel(
      key: const ValueKey('win_panel'),
      children: [
        Text(
          l10n.winTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900, color: Palette.ink),
        ),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.stars.toDouble()),
          duration: const Duration(milliseconds: 900),
          builder: (_, v, _) => StarRow(stars: v.round(), size: 48),
        ),
        const SizedBox(height: 8),
        Text(l10n.winMoves(widget.moves, widget.targetMoves)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CoinIcon(size: 32),
            const SizedBox(width: 8),
            Text(
              l10n.winCoins(_coins),
              key: const ValueKey('win_coins'),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Palette.saffronDeep,
              ),
            ),
          ],
        ),
        if (widget.boss)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.bossBonus),
          ),
        const SizedBox(height: 20),
        if (widget.canDouble && !_doubled)
          OutlinedButton.icon(
            key: const ValueKey('win_double'),
            onPressed: _busy ? null : _double,
            icon: const AdBadge(),
            label: Text(l10n.doubleCoins),
          ),
        const SizedBox(height: 10),
        FilledButton(
          key: const ValueKey('win_continue'),
          onPressed: _busy ? null : widget.onContinue,
          child: Text(l10n.continueLabel),
        ),
      ],
    );
  }
}

/// A continue option on the fail panel.
final class FailOption {
  const new({
    required this.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String key;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Fail/stuck panel: booster continues first, then retry and home.
class FailPanel extends StatelessWidget {
  const new({
    required this.status,
    required this.deadEnd,
    required this.options,
    required this.onRetry,
    required this.onHome,
    super.key,
  });

  final SessionStatus status;
  final bool deadEnd;
  final List<FailOption> options;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = status == SessionStatus.outOfMoves
        ? l10n.outOfMovesTitle
        : deadEnd
        ? l10n.deadEndTitle
        : l10n.stuckTitle;
    return _Panel(
      key: const ValueKey('fail_panel'),
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(l10n.failBody, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        for (final o in options) ...[
          FilledButton.icon(
            key: ValueKey('fail_${o.key}'),
            onPressed: o.onTap,
            icon: Icon(o.icon),
            label: Text(o.label),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('fail_home'),
                onPressed: onHome,
                child: Text(l10n.home),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('fail_retry'),
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99000000),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                builder: (_, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Palette.ivory,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Palette.saffron, width: 4),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pause menu.
class PausePanel extends StatelessWidget {
  const new({
    required this.onResume,
    required this.onRestart,
    required this.onSettings,
    required this.onHome,
    super.key,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onSettings;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Panel(
      key: const ValueKey('pause_panel'),
      children: [
        Text(
          l10n.paused,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onResume, child: Text(l10n.resume)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('pause_restart'),
          onPressed: onRestart,
          icon: const Icon(Icons.replay_rounded),
          label: Text(l10n.restart),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_rounded),
          label: Text(l10n.settings),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('pause_home'),
          onPressed: onHome,
          icon: const Icon(Icons.home_rounded),
          label: Text(l10n.home),
        ),
      ],
    );
  }
}

/// Tutorial coach bubble.
class CoachBubble extends StatelessWidget {
  const new({required this.text, required this.onDismiss, super.key});

  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 4, 12),
        decoration: BoxDecoration(
          color: Palette.night.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.tips_and_updates_rounded, color: Palette.saffron),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Palette.ivory,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: context.l10n.gotIt,
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, color: Palette.ivory),
            ),
          ],
        ),
      ),
    );
  }
}
