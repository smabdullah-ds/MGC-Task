import 'package:bazaar_sort/core/economy/booster.dart';
import 'package:bazaar_sort/core/economy/economy_config.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';
import 'package:bazaar_sort/core/economy/progression.dart';
import 'package:bazaar_sort/core/economy/save_migrations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = EconomyConfig();
  const p = Progression();

  group('EconomyConfig', () {
    test('level coins: base + per star + boss bonus', () {
      expect(config.levelCoins(stars: 3, boss: false), 50);
      expect(config.levelCoins(stars: 1, boss: true), 80);
    });
    test('prices per booster', () {
      expect(config.priceOf(BoosterType.extraShelf), 120);
      expect(config.priceOf(BoosterType.hint), 60);
      expect(config.priceOf(BoosterType.shuffle), 80);
      expect(config.priceOf(BoosterType.undo), 50);
    });
  });

  group('Progression', () {
    test('first clear advances and pays full coins', () {
      final r = p.completeLevel(
        const PlayerState(),
        level: 1,
        stars: 3,
        boss: false,
      );
      expect(r.firstClear, isTrue);
      expect(r.coins, 50);
      expect(r.state.nextLevel, 2);
      expect(r.state.coins, 50);
      expect(r.state.stars[1], 3);
      expect(r.state.levelsCompleted, 1);
      expect(r.state.lastWin!.coins, 50);
    });

    test('replay pays base coins and keeps best stars', () {
      final first = p.completeLevel(
        const PlayerState(),
        level: 1,
        stars: 3,
        boss: false,
      );
      final replay = p.completeLevel(
        first.state,
        level: 1,
        stars: 1,
        boss: false,
      );
      expect(replay.firstClear, isFalse);
      expect(replay.coins, config.coinsBase);
      expect(replay.state.nextLevel, 2);
      expect(replay.state.stars[1], 3);
    });

    test('double last win exactly once', () {
      final won = p
          .completeLevel(const PlayerState(), level: 1, stars: 2, boss: false)
          .state;
      final doubled = p.doubleLastWin(won)!;
      expect(doubled.coins, won.coins * 2);
      expect(p.doubleLastWin(doubled), isNull);
      expect(p.doubleLastWin(const PlayerState()), isNull);
    });

    test('spend, earn and boosters', () {
      const s = PlayerState(coins: 100);
      expect(p.spend(s, 150), isNull);
      expect(p.spend(s, 100)!.coins, 0);
      expect(p.earn(s, 5).coins, 105);
      final withHint = p.addBooster(s, BoosterType.hint, 2);
      expect(withHint.boosterCount(BoosterType.hint), 2);
      expect(
        p
            .useBooster(withHint, BoosterType.hint)!
            .boosterCount(BoosterType.hint),
        1,
      );
      expect(p.useBooster(s, BoosterType.hint), isNull);
      expect(p.buyBooster(s, BoosterType.hint)!.coins, 40);
      expect(p.buyBooster(const PlayerState(), BoosterType.hint), isNull);
    });
  });

  group('PlayerState JSON', () {
    test('round-trips every field', () {
      final s = PlayerState(
        nextLevel: 12,
        stars: const {1: 3, 2: 2},
        coins: 999,
        boosters: const {BoosterType.hint: 2, BoosterType.undo: 1},
        restoredItems: const {'spice_awning'},
        claimedAreas: const {'spice_market'},
        daily: const DailyState(
          lastLoginClaim: '2026-01-01',
          loginDay: 3,
          lastChallengeWin: '2026-01-01',
          challengeStreak: 2,
          lastFreeSpin: '2026-01-01',
        ),
        purchases: PurchaseState(
          grantedTransactions: const {'tx1'},
          removeAds: true,
          vipExpiresAt: DateTime.utc(2030),
          lastVipGrant: '2026-01-01',
          starterPackBought: true,
          starterOfferStartedAt: DateTime.utc(2026),
          isPayer: true,
        ),
        settings: const PlayerSettings(
          sound: false,
          colorblind: true,
          localeCode: 'de',
          notificationsOptIn: true,
          notificationsAsked: true,
        ),
        lastWin: const LastWin(level: 11, coins: 50, doubled: true),
        installedAt: DateTime.utc(2025, 12, 31),
        levelsCompleted: 11,
        tutorialStepsSeen: const {'pick'},
      );
      final back = SaveMigrations.load(s.toJson());
      expect(back.toJson(), s.toJson());
      expect(back.totalStars, 5);
      expect(back.purchases.vipActiveAt(DateTime.utc(2029)), isTrue);
      expect(back.purchases.vipActiveAt(DateTime.utc(2031)), isFalse);
    });

    test('empty json gives defaults', () {
      final s = PlayerState.fromJson(const {});
      expect(s.nextLevel, 1);
      expect(s.coins, 0);
      expect(s.settings.sound, isTrue);
    });

    test('copyWith helpers', () {
      const settings = PlayerSettings(localeCode: 'ar');
      expect(settings.copyWith(clearLocale: true).localeCode, isNull);
      expect(settings.copyWith(music: false).music, isFalse);
      final purchases = PurchaseState(vipExpiresAt: DateTime.utc(2030));
      expect(purchases.copyWith(clearVip: true).vipExpiresAt, isNull);
    });
  });

  group('SaveMigrations', () {
    test('migrates a v1 save', () {
      final s = SaveMigrations.load(const {
        'level': 7,
        'coins': 320,
        'stars': [
          [1, 3],
          [2, 2],
        ],
        'sound': false,
      });
      expect(s.nextLevel, 7);
      expect(s.coins, 320);
      expect(s.stars, {1: 3, 2: 2});
      expect(s.settings.sound, isFalse);
      expect(s.settings.music, isTrue);
    });

    test('current saves pass through and are stamped', () {
      final json = const PlayerState(coins: 5).toJson();
      expect(json['v'], PlayerState.schemaVersion);
      expect(SaveMigrations.migrate(json)['coins'], 5);
    });

    test('newer saves are left as they are', () {
      final m = SaveMigrations.migrate(const {'v': 99, 'coins': 1});
      expect(m['v'], 99);
    });
  });
}
