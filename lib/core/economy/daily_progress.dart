import 'package:bazaar_sort/core/economy/booster.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';

/// One day of the 7-day login calendar.
final class DailyReward {
  /// Creates a reward.
  const new({this.coins = 0, this.booster, this.boosterCount = 0});

  /// Coins granted.
  final int coins;

  /// Booster granted, if any.
  final BoosterType? booster;

  /// How many of [booster].
  final int boosterCount;
}

/// The 7-day login calendar, the daily challenge streak and the free spin.
/// Days are local calendar days (`yyyy-mm-dd`).
final class DailyProgress {
  /// Creates the rules.
  const new({this.challengeReward = 100});

  /// Coins for winning the daily challenge (before the streak bonus).
  final int challengeReward;

  /// The calendar: day 7 is the big one.
  static const List<DailyReward> calendar = [
    DailyReward(coins: 50),
    DailyReward(coins: 75),
    DailyReward(booster: BoosterType.hint, boosterCount: 1, coins: 50),
    DailyReward(coins: 100),
    DailyReward(booster: BoosterType.shuffle, boosterCount: 1, coins: 75),
    DailyReward(coins: 150),
    DailyReward(coins: 300, booster: BoosterType.extraShelf, boosterCount: 1),
  ];

  /// `yyyy-mm-dd` for [d].
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static bool _isYesterday(String? key, DateTime now) =>
      key != null && key == dayKey(DateTime(now.year, now.month, now.day - 1));

  /// Whether today's login reward can be claimed.
  bool canClaimLogin(PlayerState s, DateTime now) =>
      s.daily.lastLoginClaim != dayKey(now);

  /// Calendar index (0–6) the next claim pays out. Missing a day restarts
  /// the calendar; finishing day 7 starts over.
  int nextLoginDay(PlayerState s, DateTime now) {
    final last = s.daily.lastLoginClaim;
    if (last == null || !_isYesterday(last, now)) {
      return last == dayKey(now) ? s.daily.loginDay : 0;
    }
    return s.daily.loginDay % calendar.length;
  }

  /// Claims today's login reward. `null` if already claimed today.
  (PlayerState, DailyReward)? claimLogin(PlayerState s, DateTime now) {
    if (!canClaimLogin(s, now)) return null;
    final day = nextLoginDay(s, now);
    final reward = calendar[day];
    final boosters = {...s.boosters};
    if (reward.booster != null) {
      boosters[reward.booster!] =
          (boosters[reward.booster!] ?? 0) + reward.boosterCount;
    }
    return (
      s.copyWith(
        coins: s.coins + reward.coins,
        boosters: boosters,
        daily: s.daily.copyWith(
          lastLoginClaim: dayKey(now),
          loginDay: (day + 1) % calendar.length,
        ),
      ),
      reward,
    );
  }

  /// Whether today's challenge is already won.
  bool challengeDoneToday(PlayerState s, DateTime now) =>
      s.daily.lastChallengeWin == dayKey(now);

  /// Current challenge streak as seen today (0 if it lapsed).
  int challengeStreak(PlayerState s, DateTime now) {
    final last = s.daily.lastChallengeWin;
    if (last == dayKey(now) || _isYesterday(last, now)) {
      return s.daily.challengeStreak;
    }
    return 0;
  }

  /// Whether the streak will be lost if today's challenge isn't won.
  bool streakAtRisk(PlayerState s, DateTime now) =>
      !challengeDoneToday(s, now) && challengeStreak(s, now) > 0;

  /// Records a challenge win. Returns the new state and coins granted, or
  /// `null` if today's challenge was already won (replays pay nothing).
  (PlayerState, int)? completeChallenge(PlayerState s, DateTime now) {
    if (challengeDoneToday(s, now)) return null;
    final streak = challengeStreak(s, now) + 1;
    // +20 coins per consecutive day, capped at a 7-day streak.
    final coins = challengeReward + 20 * (streak.clamp(1, 7) - 1);
    return (
      s.copyWith(
        coins: s.coins + coins,
        daily: s.daily.copyWith(
          lastChallengeWin: dayKey(now),
          challengeStreak: streak,
        ),
      ),
      coins,
    );
  }

  /// Whether the free daily spin (rewarded ad) is available.
  bool canSpin(PlayerState s, DateTime now) =>
      s.daily.lastFreeSpin != dayKey(now);

  /// Spin prizes, in wheel order.
  static const List<DailyReward> wheel = [
    DailyReward(coins: 25),
    DailyReward(booster: BoosterType.hint, boosterCount: 1),
    DailyReward(coins: 50),
    DailyReward(booster: BoosterType.undo, boosterCount: 3),
    DailyReward(coins: 100),
    DailyReward(booster: BoosterType.shuffle, boosterCount: 1),
    DailyReward(coins: 40),
    DailyReward(booster: BoosterType.extraShelf, boosterCount: 1),
  ];

  /// Applies the spin landing on [slot]. `null` if already spun today.
  (PlayerState, DailyReward)? spin(PlayerState s, DateTime now, int slot) {
    if (!canSpin(s, now)) return null;
    final reward = wheel[slot % wheel.length];
    final boosters = {...s.boosters};
    if (reward.booster != null) {
      boosters[reward.booster!] =
          (boosters[reward.booster!] ?? 0) + reward.boosterCount;
    }
    return (
      s.copyWith(
        coins: s.coins + reward.coins,
        boosters: boosters,
        daily: s.daily.copyWith(lastFreeSpin: dayKey(now)),
      ),
      reward,
    );
  }
}
