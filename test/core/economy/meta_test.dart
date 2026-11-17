import 'package:bazaar_sort/core/economy/bazaar_catalog.dart';
import 'package:bazaar_sort/core/economy/booster.dart';
import 'package:bazaar_sort/core/economy/daily_progress.dart';
import 'package:bazaar_sort/core/economy/interstitial_policy.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';
import 'package:bazaar_sort/core/level_gen/seeded_random.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InterstitialPolicy', () {
    final t0 = DateTime(2026, 1, 1, 12);
    InterstitialPolicy fixedGap(int gap) => InterstitialPolicy(
      config: InterstitialConfig(levelGapMin: gap, levelGapMax: gap),
      random: SeededRandom(1),
    );

    InterstitialDecision decide(
      InterstitialPolicy p, {
      int level = 20,
      DateTime? at,
      bool adFree = false,
      bool hadFailure = false,
    }) => p.decide(
      level: level,
      now: at ?? t0,
      adFree: adFree,
      hadFailure: hadFailure,
    );

    test('never before level 10 or for ad-free players', () {
      final p = fixedGap(1)..recordLevelComplete();
      expect(decide(p, level: 9), InterstitialDecision.tutorial);
      expect(decide(p, adFree: true), InterstitialDecision.adFree);
      expect(
        InterstitialPolicy(config: const InterstitialConfig(enabled: false))
            .decide(level: 50, now: t0, adFree: false, hadFailure: false),
        InterstitialDecision.disabled,
      );
    });

    test('waits for the level gap', () {
      final p = fixedGap(2)..recordLevelComplete();
      expect(decide(p), InterstitialDecision.levelGap);
      p.recordLevelComplete();
      expect(decide(p), InterstitialDecision.show);
      expect(p.levelsSinceLast, 2);
    });

    test('90 s cooldown between interstitials', () {
      final p = fixedGap(1)
        ..recordShown(t0)
        ..recordLevelComplete();
      expect(
        decide(p, at: t0.add(const Duration(seconds: 60))),
        InterstitialDecision.cooldown,
      );
      expect(
        decide(p, at: t0.add(const Duration(seconds: 91))),
        InterstitialDecision.show,
      );
    });

    test('3 minutes off after a rewarded ad', () {
      final p = fixedGap(1)
        ..lastRewardedAt = t0
        ..recordLevelComplete();
      expect(
        decide(p, at: t0.add(const Duration(minutes: 2))),
        InterstitialDecision.afterRewarded,
      );
      expect(
        decide(p, at: t0.add(const Duration(minutes: 4))),
        InterstitialDecision.show,
      );
    });

    test('never after a level that was failed first', () {
      final p = fixedGap(1)..recordLevelComplete();
      expect(decide(p, hadFailure: true), InterstitialDecision.hadFailure);
    });

    test('gap is between 2 and 3 levels by default', () {
      for (var seed = 0; seed < 20; seed++) {
        final p = InterstitialPolicy(random: SeededRandom(seed))
          ..recordLevelComplete();
        expect(decide(p), InterstitialDecision.levelGap);
        p
          ..recordLevelComplete()
          ..recordLevelComplete();
        expect(decide(p), InterstitialDecision.show);
      }
    });
  });

  group('DailyProgress', () {
    const daily = DailyProgress();
    final day1 = DateTime(2026, 3, 10, 9);
    final day2 = DateTime(2026, 3, 11, 23);
    final day4 = DateTime(2026, 3, 13, 8);

    test('day keys', () {
      expect(DailyProgress.dayKey(DateTime(2026, 1, 2)), '2026-01-02');
    });

    test('login calendar advances on consecutive days and resets on a gap', () {
      final (s1, r1) = daily.claimLogin(const PlayerState(), day1)!;
      expect(r1.coins, DailyProgress.calendar[0].coins);
      expect(daily.claimLogin(s1, day1), isNull);
      expect(daily.canClaimLogin(s1, day2), isTrue);
      final (s2, r2) = daily.claimLogin(s1, day2)!;
      expect(r2.coins, DailyProgress.calendar[1].coins);
      expect(daily.nextLoginDay(s2, day4), 0, reason: 'missed a day');
      expect(daily.nextLoginDay(s2, day2), 2);
    });

    test('day 3 grants a booster; day 7 wraps around', () {
      var s = const PlayerState();
      for (var i = 0; i < 7; i++) {
        s = daily.claimLogin(s, DateTime(2026, 3, 1 + i))!.$1;
      }
      expect(s.boosterCount(BoosterType.hint), 1);
      expect(s.boosterCount(BoosterType.extraShelf), 1);
      expect(s.daily.loginDay, 0);
    });

    test('challenge streak grows, lapses and pays once a day', () {
      final (s1, c1) = daily.completeChallenge(const PlayerState(), day1)!;
      expect(c1, 100);
      expect(daily.completeChallenge(s1, day1), isNull);
      expect(daily.challengeDoneToday(s1, day1), isTrue);
      expect(daily.streakAtRisk(s1, day2), isTrue);
      final (s2, c2) = daily.completeChallenge(s1, day2)!;
      expect(s2.daily.challengeStreak, 2);
      expect(c2, 120);
      expect(daily.challengeStreak(s2, day4), 0);
      expect(daily.streakAtRisk(s2, day4), isFalse);
      expect(daily.completeChallenge(s2, day4)!.$1.daily.challengeStreak, 1);
    });

    test('free spin once a day', () {
      final (s, prize) = daily.spin(const PlayerState(), day1, 3)!;
      expect(prize.booster, BoosterType.undo);
      expect(s.boosterCount(BoosterType.undo), 3);
      expect(daily.spin(s, day1, 0), isNull);
      expect(daily.canSpin(s, day2), isTrue);
      expect(daily.spin(s, day2, 0)!.$1.coins, 25);
    });
  });

  group('BazaarCatalog', () {
    const catalog = BazaarCatalog();
    final first = BazaarCatalog.areas.first;

    test('four areas of 6–8 items with rising costs', () {
      expect(BazaarCatalog.areas, hasLength(4));
      var lastMax = 0;
      for (final a in BazaarCatalog.areas) {
        expect(a.items.length, inInclusiveRange(6, 8));
        final costs = a.items.map((i) => i.baseCost).toList();
        expect(costs.every((c) => c >= 150 && c <= 600), isTrue);
        expect(costs.first, greaterThanOrEqualTo(lastMax - 120));
        lastMax = costs.last;
      }
    });

    test('area 1 costs about 25 levels of coins for a non-payer', () {
      // ~48 coins/level + ~100/day login over ~3 days of play.
      const perLevel = 48;
      final levels = (first.totalBaseCost - 300) / perLevel;
      expect(levels, inInclusiveRange(18, 32));
    });

    test('restore spends coins and completes areas with a reward', () {
      var s = const PlayerState(coins: 100000);
      expect(catalog.currentArea(s).id, 'spice_market');
      expect(catalog.isUnlocked(s, BazaarCatalog.areas[1]), isFalse);
      expect(catalog.restore(s, 'lantern_arch'), isNull, reason: 'locked');
      RestoreResult? last;
      for (final item in first.items) {
        last = catalog.restore(s, item.id);
        expect(last, isNotNull);
        s = last!.state;
      }
      expect(last!.completedArea?.id, 'spice_market');
      expect(s.claimedAreas, contains('spice_market'));
      expect(s.boosterCount(BoosterType.hint), 2);
      expect(catalog.isUnlocked(s, BazaarCatalog.areas[1]), isTrue);
      expect(catalog.currentArea(s).id, 'lantern_street');
      expect(catalog.progress(s, first), 1);
      expect(catalog.nextItem(s)!.id, 'lantern_arch');
    });

    test('restore rejects unknown, duplicate and unaffordable items', () {
      const poor = PlayerState(coins: 10);
      expect(catalog.restore(poor, 'spice_awning'), isNull);
      expect(catalog.restore(poor, 'nope'), isNull);
      final s = catalog.restore(
        const PlayerState(coins: 1000),
        'spice_awning',
      )!;
      expect(s.cost, 150);
      expect(catalog.restore(s.state, 'spice_awning'), isNull);
    });

    test('multiplier rounds to 5 coins', () {
      const pricey = BazaarCatalog(multiplier: 1.13);
      expect(pricey.costOf(first.items.first) % 5, 0);
      expect(BazaarCatalog.areaOf('tea_dome').id, 'tea_house');
    });

    test('everything restored keeps the last area current', () {
      final all = {
        for (final a in BazaarCatalog.areas)
          for (final i in a.items) i.id,
      };
      final s = PlayerState(restoredItems: all);
      expect(catalog.currentArea(s).id, 'textile_lane');
      expect(catalog.nextItem(s), isNull);
    });
  });
}
