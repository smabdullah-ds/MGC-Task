import 'package:bazaar_sort/core/economy/daily_progress.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';
import 'package:bazaar_sort/core/economy/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = ReminderPlanner();
  const optedIn = PlayerState(
    settings: PlayerSettings(notificationsOptIn: true),
  );
  final morning = DateTime(2026, 6, 1, 10);

  test('nothing without opt-in', () {
    expect(planner.plan(const PlayerState(), morning), isEmpty);
  });

  test('at most one per day, never in quiet hours', () {
    final plan = planner.plan(optedIn, morning, daysAhead: 6);
    final days = plan.map((r) => DailyProgress.dayKey(r.at)).toSet();
    expect(days.length, plan.length);
    for (final r in plan) {
      expect(planner.isQuiet(r.at), isFalse, reason: '$r');
      expect(r.at.isAfter(morning), isTrue);
    }
    expect(plan.first.kind, ReminderKind.dailyRewardReady);
  });

  test('streak at risk today when the challenge is not done', () {
    final s = optedIn.copyWith(
      daily: const DailyState(
        lastChallengeWin: '2026-05-31',
        challengeStreak: 3,
      ),
    );
    final plan = planner.plan(s, morning);
    expect(plan.first.kind, ReminderKind.streakAtRisk);
    expect(plan.first.at.day, 1);
    expect(plan.first.at.hour, 19);
  });

  test('late evening skips today', () {
    final late = DateTime(2026, 6, 1, 21);
    final plan = planner.plan(optedIn, late);
    expect(plan.every((r) => r.at.day != 1), isTrue);
  });

  test('a freshly unlocked area gets a reminder on day 2', () {
    const s = PlayerState(
      settings: PlayerSettings(notificationsOptIn: true),
      restoredItems: {
        'spice_awning',
        'spice_sacks',
        'spice_scales',
        'spice_counter',
        'spice_lamps',
        'spice_sign',
      },
    );
    final plan = planner.plan(s, morning);
    expect(plan.map((r) => r.kind), contains(ReminderKind.areaUnlocked));
  });

  test('streak continues tomorrow when done today', () {
    final s = optedIn.copyWith(
      daily: DailyState(
        lastChallengeWin: DailyProgress.dayKey(morning),
        challengeStreak: 2,
      ),
    );
    final plan = planner.plan(s, morning);
    expect(plan.first.kind, ReminderKind.streakAtRisk);
    expect(plan.first.at.day, 2);
  });

  test('quiet hours handle both wrap-around and same-day windows', () {
    expect(planner.isQuiet(DateTime(2026, 1, 1, 23)), isTrue);
    expect(planner.isQuiet(DateTime(2026, 1, 1, 8)), isTrue);
    expect(planner.isQuiet(DateTime(2026, 1, 1, 12)), isFalse);
    const sameDay = ReminderPlanner(quietStartHour: 13, quietEndHour: 15);
    expect(sameDay.isQuiet(DateTime(2026, 1, 1, 14)), isTrue);
    expect(sameDay.isQuiet(DateTime(2026, 1, 1, 16)), isFalse);
    const misconfigured = ReminderPlanner(preferredHour: 23);
    final plan = misconfigured.plan(optedIn, morning);
    expect(plan.every((r) => r.at.hour == 9), isTrue);
    expect(plan.first.toString(), contains('Reminder('));
  });
}
