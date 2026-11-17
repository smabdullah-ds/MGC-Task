import 'dart:async';

import 'package:bazaar_sort/config/remote_config_defaults.dart';
import 'package:bazaar_sort/core/economy/daily_progress.dart';
import 'package:bazaar_sort/core/economy/interstitial_policy.dart';
import 'package:bazaar_sort/core/economy/progression.dart';
import 'package:bazaar_sort/core/game_logic/star_rating.dart';
import 'package:bazaar_sort/core/level_gen/generated_level.dart';
import 'package:bazaar_sort/features/gameplay/controller/game_controller.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/services/ads/ad_types.dart';
import 'package:bazaar_sort/services/remote_config/tuning.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the win panel shows.
final class WinResult {
  /// Creates a result.
  const new({
    required this.stars,
    required this.coins,
    required this.moves,
    required this.threeStarMoves,
  });

  /// Stars earned.
  final int stars;

  /// Coins granted (already saved).
  final int coins;

  /// Moves used.
  final int moves;

  /// Largest move count that earns 3 stars.
  final int threeStarMoves;
}

/// Everything that happens *around* a level: saving wins, analytics, the
/// 2× coins offer and interstitial pacing. Kept out of widgets so the rules
/// are in one place and testable.
class LevelFlow {
  /// Creates the flow.
  new(this._ref);

  final Ref _ref;
  final Set<int> _failedLevels = <int>{};
  final Map<int, int> _attempts = <int, int>{};

  /// Interstitial pacing for this session.
  late final InterstitialPolicy policy = InterstitialPolicy(
    config: _interstitialConfig(),
  );

  InterstitialConfig _interstitialConfig() {
    final rc = _ref.read(remoteConfigServiceProvider);
    return InterstitialConfig(
      enabled: rc.getBool(RcKeys.interstitialsEnabled),
      minLevel: rc.getInt(RcKeys.interstitialMinLevel),
      levelGapMin: rc.getInt(RcKeys.interstitialLevelGapMin),
      levelGapMax: rc.getInt(RcKeys.interstitialLevelGapMax),
      cooldown: Duration(
        seconds: rc.getInt(RcKeys.interstitialCooldownSeconds),
      ),
      afterRewarded: Duration(
        seconds: rc.getInt(RcKeys.interstitialPostRewardedSeconds),
      ),
    );
  }

  /// Clock (overridable in tests).
  DateTime Function() now = DateTime.now;

  /// A level attempt began.
  void onLevelStart(GeneratedLevel level, {required bool daily}) {
    final attempt = _attempts.update(
      level.level,
      (v) => v + 1,
      ifAbsent: () => 1,
    );
    _ref
        .read(gameAnalyticsProvider)
        .levelStart(
          level: level.level,
          kind: daily ? 'daily' : level.kind.name,
          attempt: attempt,
        );
  }

  /// Saves the win (progress + coins in one write) and returns what to show.
  Future<WinResult> onLevelWon(
    GeneratedLevel level, {
    required GameController controller,
    required bool daily,
  }) async {
    final cfg = _ref.read(economyConfigProvider);
    final rating = StarRating(
      threeStarRatio: cfg.threeStarRatio,
      twoStarRatio: cfg.twoStarRatio,
    );
    final moves = controller.session.movesMade;
    final stars = rating.stars(moves: moves, optimalMoves: level.optimalMoves);
    final store = _ref.read(playerProvider.notifier);
    final analytics = _ref.read(gameAnalyticsProvider);
    var coins = 0;

    if (daily) {
      final rules = DailyProgress(challengeReward: cfg.dailyChallengeReward);
      final result = rules.completeChallenge(store.current, now());
      if (result != null) {
        coins = result.$2;
        await store.update((_) => result.$1);
        analytics.dailyChallengeComplete(
          streak: result.$1.daily.challengeStreak,
          moves: moves,
        );
      }
    } else {
      final completion = Progression(cfg).completeLevel(
        store.current,
        level: level.level,
        stars: stars,
        boss: level.isBoss,
      );
      coins = completion.coins;
      await store.update((_) => completion.state);
      policy.recordLevelComplete();
    }

    analytics
      ..levelComplete(
        level: level.level,
        moves: moves,
        optimalMoves: level.optimalMoves,
        stars: stars,
        durationS: controller.elapsedSeconds,
        boostersUsed: controller.boostersUsed.values.fold(0, (a, b) => a + b),
      )
      ..coinsEarned(amount: coins, source: daily ? 'daily_challenge' : 'level');
    return WinResult(
      stars: stars,
      coins: coins,
      moves: moves,
      threeStarMoves: rating.movesFor(3, level.optimalMoves),
    );
  }

  /// The attempt failed (stuck, out of moves or quit).
  void onLevelFail(
    GeneratedLevel level, {
    required GameController controller,
    required String reason,
  }) {
    _failedLevels.add(level.level);
    _ref
        .read(gameAnalyticsProvider)
        .levelFail(
          level: level.level,
          reason: reason,
          moves: controller.session.movesMade,
          durationS: controller.elapsedSeconds,
        );
  }

  /// The player restarted.
  void onRestart(GeneratedLevel level, {required GameController controller}) {
    _failedLevels.add(level.level);
    _ref
        .read(gameAnalyticsProvider)
        .levelRestart(level: level.level, moves: controller.session.movesMade);
    onLevelStart(level, daily: false);
  }

  /// A rewarded ad finished: interstitials pause for a while.
  void onRewardedShown() => policy.lastRewardedAt = now();

  /// Shows a rewarded ad and grants the 2× coins bonus once.
  Future<bool> doubleCoins(GeneratedLevel level) async {
    final ads = _ref.read(adsServiceProvider);
    final analytics = _ref.read(gameAnalyticsProvider)
      ..adRequest(format: 'rewarded', placement: 'double_coins');
    if (!await ads.showRewarded(RewardedPlacement.doubleCoins)) return false;
    onRewardedShown();
    analytics.adRewardGranted(placement: 'double_coins');
    final store = _ref.read(playerProvider.notifier);
    final before = store.current.coins;
    final next = await store.update(
      (p) => Progression(_ref.read(economyConfigProvider)).doubleLastWin(p),
    );
    if (next == null) return false;
    analytics.coinsEarned(amount: next.coins - before, source: 'double_coins');
    return true;
  }

  /// Called when the player leaves the win panel; may show an interstitial.
  Future<void> beforeLeavingWin(
    GeneratedLevel level, {
    required bool daily,
  }) async {
    final hadFailure = _failedLevels.remove(level.level);
    if (daily) return;
    final player = _ref.read(playerProvider);
    final at = now();
    final decision = policy.decide(
      level: level.level,
      now: at,
      adFree: player.purchases.removeAds || player.purchases.vipActiveAt(at),
      hadFailure: hadFailure,
    );
    if (decision != InterstitialDecision.show) return;
    final ads = _ref.read(adsServiceProvider);
    if (!ads.isInterstitialReady) return;
    _ref
        .read(gameAnalyticsProvider)
        .adRequest(format: 'interstitial', placement: 'level_complete');
    final feedback = _ref.read(feedbackServiceProvider)..pauseMusic();
    final shown = await ads.showInterstitial('level_complete');
    feedback.resumeMusic();
    if (shown) policy.recordShown(now());
  }
}

/// One flow per app session (pacing state is in memory by design).
final levelFlowProvider = Provider<LevelFlow>(LevelFlow.new);
