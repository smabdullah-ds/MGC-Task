import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:bazaar_sort/config/remote_config_defaults.dart';
import 'package:bazaar_sort/core/economy/reminder_planner.dart';
import 'package:bazaar_sort/features/meta/bazaar_providers.dart';
import 'package:bazaar_sort/features/player/player_store.dart';
import 'package:bazaar_sort/l10n/gen/app_localizations.dart';
import 'package:bazaar_sort/services/notifications/notification_service.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opt-in, locally scheduled reminders (daily reward, streak at risk, new
/// bazaar area). Plans come from [ReminderPlanner]; this class handles
/// permission, localisation and scheduling.
class ReminderScheduler {
  /// Creates the scheduler.
  new(this._ref);

  final Ref _ref;

  /// Clock (overridable in tests).
  DateTime Function() now = DateTime.now;

  ReminderPlanner _planner() {
    final rc = _ref.read(remoteConfigServiceProvider);
    return ReminderPlanner(
      quietStartHour: rc.getInt(RcKeys.quietHoursStart),
      quietEndHour: rc.getInt(RcKeys.quietHoursEnd),
      catalog: _ref.read(bazaarCatalogProvider),
    );
  }

  /// Asks for permission (after the player said yes in-game) and records
  /// the answer. Returns whether reminders are now on.
  Future<bool> optIn() async {
    final granted = await _ref
        .read(notificationServiceProvider)
        .requestPermission();
    await _ref
        .read(playerProvider.notifier)
        .update(
          (p) => p.copyWith(
            settings: p.settings.copyWith(
              notificationsOptIn: granted,
              notificationsAsked: true,
            ),
          ),
        );
    _ref
        .read(gameAnalyticsProvider)
        .settingsChanged(setting: 'notifications', value: '$granted');
    if (granted) {
      unawaited(_registerPush());
      await reschedule();
    }
    return granted;
  }

  /// Records that the player declined the in-game prompt.
  Future<void> decline() => _ref
      .read(playerProvider.notifier)
      .update(
        (p) =>
            p.copyWith(settings: p.settings.copyWith(notificationsAsked: true)),
      );

  /// Turns reminders off.
  Future<void> optOut() async {
    await _ref
        .read(playerProvider.notifier)
        .update(
          (p) => p.copyWith(
            settings: p.settings.copyWith(notificationsOptIn: false),
          ),
        );
    await _ref.read(notificationServiceProvider).cancelAll();
    _ref
        .read(gameAnalyticsProvider)
        .settingsChanged(setting: 'notifications', value: 'false');
  }

  /// Re-plans everything. Called when the app goes to the background.
  Future<void> reschedule() async {
    final player = _ref.read(playerProvider);
    final service = _ref.read(notificationServiceProvider);
    final rc = _ref.read(remoteConfigServiceProvider);
    if (!player.settings.notificationsOptIn ||
        !rc.getBool(RcKeys.notificationsEnabled)) {
      await service.cancelAll();
      return;
    }
    final l10n = _strings(player.settings.localeCode);
    final plan = _planner().plan(player, now());
    await service.replaceSchedule([
      for (final r in plan)
        ScheduledNotification(
          kind: switch (r.kind) {
            ReminderKind.streakAtRisk => NotificationKind.streakAtRisk,
            ReminderKind.dailyRewardReady => NotificationKind.dailyRewardReady,
            ReminderKind.areaUnlocked => NotificationKind.areaUnlocked,
          },
          when: r.at,
          title: switch (r.kind) {
            ReminderKind.streakAtRisk => l10n.notifStreakTitle,
            ReminderKind.dailyRewardReady => l10n.notifDailyTitle,
            ReminderKind.areaUnlocked => l10n.notifAreaTitle,
          },
          body: switch (r.kind) {
            ReminderKind.streakAtRisk => l10n.notifStreakBody,
            ReminderKind.dailyRewardReady => l10n.notifDailyBody,
            ReminderKind.areaUnlocked => l10n.notifAreaBody,
          },
        ),
    ]);
  }

  AppLocalizations _strings(String? code) {
    final device = PlatformDispatcher.instance.locale;
    final wanted = code != null ? Locale(code) : device;
    final supported = AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == wanted.languageCode,
    );
    return lookupAppLocalizations(
      supported ? Locale(wanted.languageCode) : const Locale('en'),
    );
  }

  /// Registers for Cloud Messaging (server-sent live-ops pushes) once the
  /// player opted in. No-op without Firebase.
  Future<void> _registerPush() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      unawaited(
        messaging.onRegistered.first.then(
          (_) =>
              _ref.read(analyticsServiceProvider).breadcrumb('fcm registered'),
        ),
      );
      await messaging.register();
    } on Object catch (e, st) {
      unawaited(
        _ref
            .read(analyticsServiceProvider)
            .recordError(e, st, reason: 'fcm_register'),
      );
    }
  }
}

/// Reminder scheduling.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  ReminderScheduler.new,
);
