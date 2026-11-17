import 'dart:async';

import 'package:bazaar_sort/services/analytics/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// [AnalyticsService] on Firebase Analytics + Crashlytics.
///
/// Crashlytics' crash-free-users metric is collected automatically once
/// fatal Flutter and platform errors are routed here (see
/// [installErrorHandlers]).
class FirebaseAnalyticsService implements AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  @override
  Future<void> initialize() async {
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  }

  /// Routes uncaught Flutter and platform errors to Crashlytics as fatal.
  void installErrorHandlers() {
    FlutterError.onError = _crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(_crashlytics.recordError(error, stack, fatal: true));
      return true;
    };
  }

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object> parameters = const <String, Object>{},
  ]) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } on Object catch (e) {
      debugPrint('analytics $name failed: $e');
    }
  }

  @override
  Future<void> setUserProperty(String name, String? value) =>
      _analytics.setUserProperty(name: name, value: value);

  @override
  Future<void> setCollectionEnabled({required bool enabled}) =>
      _analytics.setAnalyticsCollectionEnabled(enabled);

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) => _crashlytics.recordError(error, stack, reason: reason, fatal: fatal);

  @override
  void breadcrumb(String message) => unawaited(_crashlytics.log(message));
}
