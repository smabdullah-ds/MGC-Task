import 'package:bazaar_sort/services/analytics/analytics_service.dart';
import 'package:flutter/foundation.dart';

/// A logged analytics event, kept in memory by [FakeAnalyticsService].
@immutable
class LoggedEvent {
  /// Creates a record of an event.
  const new(this.name, this.parameters);

  /// Event name.
  final String name;

  /// Event parameters.
  final Map<String, Object> parameters;

  @override
  String toString() => 'LoggedEvent($name, $parameters)';
}

/// In-memory analytics used in tests and when Firebase is not configured.
class FakeAnalyticsService implements AnalyticsService {
  /// Creates the fake. Set [printToConsole] to see events in debug runs.
  new({this.printToConsole = false});

  /// Whether to `debugPrint` every event.
  final bool printToConsole;

  /// Every event logged so far, oldest first.
  final List<LoggedEvent> events = <LoggedEvent>[];

  /// Current user properties.
  final Map<String, String?> userProperties = <String, String?>{};

  /// Errors recorded so far.
  final List<Object> errors = <Object>[];

  /// Breadcrumbs recorded so far.
  final List<String> breadcrumbs = <String>[];

  /// Whether collection is currently enabled.
  bool collectionEnabled = true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object> parameters = const <String, Object>{},
  ]) async {
    events.add(LoggedEvent(name, Map<String, Object>.of(parameters)));
    if (printToConsole) debugPrint('[analytics] $name $parameters');
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    userProperties[name] = value;
  }

  @override
  Future<void> setCollectionEnabled({required bool enabled}) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    errors.add(error);
    if (printToConsole) debugPrint('[analytics] error ($reason): $error');
  }

  @override
  void breadcrumb(String message) => breadcrumbs.add(message);

  /// Events with the given [name].
  Iterable<LoggedEvent> named(String name) =>
      events.where((e) => e.name == name);
}
