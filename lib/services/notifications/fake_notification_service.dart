import 'package:bazaar_sort/services/notifications/notification_service.dart';

/// Records schedules in memory.
class FakeNotificationService implements NotificationService {
  /// Creates the fake; [grant] is the permission answer.
  new({this.grant = true});

  /// Whether permission requests succeed.
  bool grant;

  /// Currently scheduled notifications.
  List<ScheduledNotification> scheduled = <ScheduledNotification>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => grant;

  @override
  Future<void> replaceSchedule(
    List<ScheduledNotification> notifications,
  ) async {
    scheduled = List<ScheduledNotification>.of(notifications);
  }

  @override
  Future<void> cancelAll() async => scheduled = <ScheduledNotification>[];
}
