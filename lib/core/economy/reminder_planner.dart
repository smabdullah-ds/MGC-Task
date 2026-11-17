import 'package:bazaar_sort/core/economy/bazaar_catalog.dart';
import 'package:bazaar_sort/core/economy/daily_progress.dart';
import 'package:bazaar_sort/core/economy/player_state.dart';

/// Kinds of reminders, in priority order (highest first).
enum ReminderKind { streakAtRisk, dailyRewardReady, areaUnlocked }

/// A planned reminder at a local time.
final class Reminder {
  /// Creates a reminder.
  const new(this.kind, this.at);

  /// What it is about.
  final ReminderKind kind;

  /// Local fire time.
  final DateTime at;

  @override
  String toString() => 'Reminder(${kind.name} @ $at)';
}

/// Plans opt-in re-engagement reminders for the next few days.
///
/// Rules:
/// * nothing unless the player opted in;
/// * at most one reminder per calendar day;
/// * never inside quiet hours (default 22:00–09:00 local);
/// * reminders are re-planned every time the app goes to the background,
///   so they always reflect the latest state.
final class ReminderPlanner {
  /// Creates a planner.
  const new({
    this.quietStartHour = 22,
    this.quietEndHour = 9,
    this.preferredHour = 19,
    this.preferredMinute = 0,
    this.catalog = const BazaarCatalog(),
    this.daily = const DailyProgress(),
  });

  /// Quiet hours start (inclusive).
  final int quietStartHour;

  /// Quiet hours end (exclusive).
  final int quietEndHour;

  /// Hour reminders are sent at.
  final int preferredHour;

  /// Minute reminders are sent at.
  final int preferredMinute;

  /// Bazaar data for area reminders.
  final BazaarCatalog catalog;

  /// Daily rules.
  final DailyProgress daily;

  /// Whether [t] falls inside quiet hours.
  bool isQuiet(DateTime t) => quietStartHour > quietEndHour
      ? t.hour >= quietStartHour || t.hour < quietEndHour
      : t.hour >= quietStartHour && t.hour < quietEndHour;

  DateTime _slot(DateTime day) {
    var t = DateTime(
      day.year,
      day.month,
      day.day,
      preferredHour,
      preferredMinute,
    );
    // If the preferred time is quiet (misconfigured), use the first allowed hour.
    if (isQuiet(t)) {
      t = DateTime(day.year, day.month, day.day, quietEndHour);
    }
    return t;
  }

  /// Reminders to schedule after [now] (at most one per day, up to
  /// [daysAhead] days).
  List<Reminder> plan(PlayerState s, DateTime now, {int daysAhead = 3}) {
    if (!s.settings.notificationsOptIn) return const [];
    final out = <Reminder>[];
    for (var d = 0; d <= daysAhead; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      final at = _slot(day);
      if (!at.isAfter(now.add(const Duration(minutes: 30)))) continue;
      final kind = _kindFor(s, now, d);
      if (kind != null) out.add(Reminder(kind, at));
    }
    return out;
  }

  ReminderKind? _kindFor(PlayerState s, DateTime now, int dayOffset) {
    final streak = daily.challengeStreak(s, now);
    if (dayOffset == 0) {
      // Today: only the streak warning is worth an interruption.
      return daily.streakAtRisk(s, now) ? ReminderKind.streakAtRisk : null;
    }
    if (dayOffset == 1) {
      // Tomorrow the login reward is always ready (and the streak, if any,
      // is at risk). Prefer the streak message when there is one.
      return streak > 0 && daily.challengeDoneToday(s, now)
          ? ReminderKind.streakAtRisk
          : ReminderKind.dailyRewardReady;
    }
    if (dayOffset == 2 && _areaReady(s)) return ReminderKind.areaUnlocked;
    if (dayOffset >= 2) return ReminderKind.dailyRewardReady;
    return null;
  }

  /// A freshly unlocked area with nothing restored yet.
  bool _areaReady(PlayerState s) {
    final area = catalog.currentArea(s);
    final index = BazaarCatalog.areas.indexOf(area);
    return index > 0 &&
        catalog.isUnlocked(s, area) &&
        catalog.restoredCount(s, area) == 0;
  }
}
