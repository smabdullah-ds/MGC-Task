import 'dart:async';
import 'dart:math' as math;

import 'package:bazaar_sort/app/palette.dart';
import 'package:bazaar_sort/app/routes.dart';
import 'package:bazaar_sort/core/economy/booster.dart';
import 'package:bazaar_sort/core/economy/daily_progress.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/l10n/gen/app_localizations.dart';
import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:bazaar_sort/services/audio/feedback_service.dart';
import 'package:bazaar_sort/services/remote_config/tuning.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:bazaar_sort/shared/utils/l10n.dart';
import 'package:bazaar_sort/shared/widgets/bazaar_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Localized label for a reward.
String rewardLabel(AppLocalizations l10n, DailyReward r) {
  final parts = <String>[
    if (r.coins > 0) l10n.rewardCoins(r.coins),
    if (r.booster != null)
      l10n.rewardBooster(r.boosterCount, boosterName(l10n, r.booster!)),
  ];
  return parts.join(' + ');
}

/// Localized booster name.
String boosterName(AppLocalizations l10n, BoosterType t) => switch (t) {
  BoosterType.undo => l10n.boosterUndo,
  BoosterType.extraShelf => l10n.boosterExtraShelf,
  BoosterType.hint => l10n.boosterHint,
  BoosterType.shuffle => l10n.boosterShuffle,
};

/// 7-day login calendar, daily challenge with streak, and free spin.
class DailyScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wheel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  double _wheelFrom = 0;
  double _wheelTo = 0;
  bool _spinning = false;

  DailyProgress get _daily => DailyProgress(
    challengeReward: ref.read(economyConfigProvider).dailyChallengeReward,
  );

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _claim() async {
    final store = ref.read(playerProvider.notifier);
    final now = DateTime.now();
    final day = _daily.nextLoginDay(store.current, now);
    final result = _daily.claimLogin(store.current, now);
    if (result == null) return;
    await store.update((_) => result.$1);
    ref.read(gameAnalyticsProvider)
      ..dailyRewardClaimed(day: day + 1, coins: result.$2.coins)
      ..coinsEarned(amount: result.$2.coins, source: 'daily_login');
    ref.read(feedbackServiceProvider).play(Sfx.coin);
    if (mounted) {
      _toast(context.l10n.youWon(rewardLabel(context.l10n, result.$2)));
    }
  }

  Future<void> _spin() async {
    final ads = ref.read(adsServiceProvider);
    final analytics = ref.read(gameAnalyticsProvider);
    setState(() => _spinning = true);
    final ok = await ads.showRewarded(RewardedPlacement.dailySpin);
    if (!mounted) return;
    if (!ok) {
      setState(() => _spinning = false);
      _toast(context.l10n.adUnavailable);
      return;
    }
    analytics.adRewardGranted(placement: 'daily_spin');
    final slot = math.Random().nextInt(DailyProgress.wheel.length);
    final store = ref.read(playerProvider.notifier);
    final result = _daily.spin(store.current, DateTime.now(), slot);
    if (result == null) {
      setState(() => _spinning = false);
      return;
    }
    // Saved before the animation so leaving mid-spin can't lose the prize.
    await store.update((_) => result.$1);
    if (result.$2.coins > 0) {
      analytics.coinsEarned(amount: result.$2.coins, source: 'daily_spin');
    }
    final slice = 2 * math.pi / DailyProgress.wheel.length;
    _wheelFrom = _wheelTo % (2 * math.pi);
    _wheelTo = 6 * math.pi + (2 * math.pi - slot * slice);
    await _wheel.forward(from: 0);
    if (!mounted) return;
    ref.read(feedbackServiceProvider).play(Sfx.coin);
    setState(() => _spinning = false);
    _toast(context.l10n.youWon(rewardLabel(context.l10n, result.$2)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final player = ref.watch(playerProvider);
    final now = DateTime.now();
    final daily = _daily;
    final canClaim = daily.canClaimLogin(player, now);
    final nextDay = daily.nextLoginDay(player, now);
    final streak = daily.challengeStreak(player, now);
    final challengeDone = daily.challengeDoneToday(player, now);
    final canSpin = daily.canSpin(player, now);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.daily),
        actions: [
          CoinPill(coins: player.coins),
          const SizedBox(width: 8),
        ],
      ),
      body: BazaarBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(
              title: l10n.dailyRewardsTitle,
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < DailyProgress.calendar.length; i++)
                        _DayTile(
                          day: i + 1,
                          reward: DailyProgress.calendar[i],
                          state: i < nextDay || (!canClaim && i == nextDay - 1)
                              ? _DayState.claimed
                              : i == nextDay && canClaim
                              ? _DayState.today
                              : _DayState.future,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const ValueKey('daily_claim'),
                    onPressed: canClaim ? _claim : null,
                    child: Text(canClaim ? l10n.claim : l10n.comeBackTomorrow),
                  ),
                ],
              ),
            ),
            _Section(
              title: l10n.dailyChallengeTitle,
              child: Column(
                children: [
                  Text(l10n.dailyChallengeBody, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Palette.terracotta,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.streakDays(streak),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const ValueKey('daily_challenge_play'),
                    onPressed: challengeDone
                        ? null
                        : () => context.go(Routes.dailyChallenge),
                    child: Text(
                      challengeDone
                          ? l10n.dailyChallengeDone
                          : l10n.dailyChallengePlay,
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: l10n.freeSpinTitle,
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _wheel,
                    builder: (_, _) {
                      final t = Curves.easeOutCubic.transform(_wheel.value);
                      return _Wheel(
                        angle: _wheelFrom + (_wheelTo - _wheelFrom) * t,
                        labels: [
                          for (final r in DailyProgress.wheel)
                            if (r.coins > 0)
                              '${r.coins}'
                            else
                              rewardLabel(l10n, r),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('daily_spin'),
                    onPressed: canSpin && !_spinning ? _spin : null,
                    icon: const AdBadge(),
                    label: Text(canSpin ? l10n.freeSpinButton : l10n.spinUsed),
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

enum _DayState { claimed, today, future }

class _DayTile extends StatelessWidget {
  const new({required this.day, required this.reward, required this.state});

  final int day;
  final DailyReward reward;
  final _DayState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = state == _DayState.today;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: day == 7 ? 150 : 72,
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: switch (state) {
          _DayState.claimed => Palette.sand,
          _DayState.today => Palette.saffron,
          _DayState.future => Colors.white,
        },
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: today ? Palette.terracotta : Palette.sand,
          width: today ? 3 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Text(
            l10n.dailyDay(day),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          if (state == _DayState.claimed)
            const Icon(Icons.check_circle_rounded, color: Palette.teal)
          else if (reward.booster != null)
            const Icon(Icons.auto_awesome_rounded, color: Palette.plum)
          else
            const CoinIcon(),
          Text(
            reward.booster != null ? '+${reward.coins}★' : '${reward.coins}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const new({required this.angle, required this.labels});

  final double angle;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Transform.rotate(
            angle: angle,
            child: CustomPaint(
              size: const Size.square(210),
              painter: _WheelPainter(labels),
            ),
          ),
          const Icon(
            Icons.arrow_drop_down_rounded,
            size: 48,
            color: Palette.ink,
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  new(this.labels);

  final List<String> labels;

  static const List<Color> _colors = [
    Palette.saffron,
    Palette.teal,
    Palette.terracotta,
    Palette.plum,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final slice = 2 * math.pi / labels.length;
    for (var i = 0; i < labels.length; i++) {
      final start = -math.pi / 2 - slice / 2 + i * slice;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        slice,
        true,
        Paint()..color = _colors[i % _colors.length],
      );
      final mid = start + slice / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Palette.ivory,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r * 0.6);
      canvas
        ..save()
        ..translate(
          c.dx + math.cos(mid) * r * 0.62,
          c.dy + math.sin(mid) * r * 0.62,
        )
        ..rotate(mid + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
    canvas
      ..drawCircle(
        c,
        r,
        Paint()
          ..color = Palette.woodDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      )
      ..drawCircle(c, r * 0.14, Paint()..color = Palette.woodDark);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.labels != labels;
}
