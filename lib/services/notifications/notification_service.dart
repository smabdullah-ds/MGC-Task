import 'package:flutter/foundation.dart';

/// Kinds of re-engagement notifications. The enum index is the stable
/// notification id.
enum NotificationKind { dailyRewardReady, streakAtRisk, areaUnlocked }

/// A notification to be shown at [when] (local time).
@immutable
class ScheduledNotification {
  /// Creates a scheduled notification.
  const new({
    required this.kind,
    required this.when,
    required this.title,
    required this.body,
  });

  /// What it is about.
  final NotificationKind kind;

  /// Local fire time.
  final DateTime when;

  /// Title text (already localized).
  final String title;

  /// Body text (already localized).
  final String body;
}

/// Local notifications plus the push token from Cloud Messaging.
abstract interface class NotificationService {
  /// Sets up channels and timezone data. Does not prompt.
  Future<void> initialize();

  /// Asks the OS for permission. Only call after the player opted in.
  Future<bool> requestPermission();

  /// Replaces every pending notification with [notifications].
  Future<void> replaceSchedule(List<ScheduledNotification> notifications);

  /// Cancels everything.
  Future<void> cancelAll();
}
