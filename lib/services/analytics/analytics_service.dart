/// Product analytics and crash reporting.
///
/// Event and parameter names are defined in `analytics_events.dart`; never
/// pass ad-hoc strings so dashboards stay consistent.
abstract interface class AnalyticsService {
  /// Prepares the backend. Safe to call more than once.
  Future<void> initialize();

  /// Logs [name] with optional [parameters]. Values must be `String`, `int`
  /// or `double` (Firebase's rules).
  Future<void> logEvent(String name, [Map<String, Object> parameters]);

  /// Sets a user property used for audience segmentation.
  Future<void> setUserProperty(String name, String? value);

  /// Enables or disables collection (tied to consent).
  Future<void> setCollectionEnabled({required bool enabled});

  /// Records a non-fatal error with context for Crashlytics.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  });

  /// Adds a breadcrumb that is attached to subsequent crash reports.
  void breadcrumb(String message);
}
