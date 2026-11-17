import 'package:bazaar_sort/config/remote_config_defaults.dart';
import 'package:bazaar_sort/services/remote_config/remote_config_service.dart';

/// Remote config backed by the local defaults plus optional overrides.
///
/// Used offline, in tests and when Firebase is not configured.
class FakeRemoteConfigService implements RemoteConfigService {
  /// Creates the fake with optional per-key [overrides].
  new([Map<String, Object>? overrides])
    : _values = <String, Object>{...remoteConfigDefaults, ...?overrides};

  final Map<String, Object> _values;

  /// Changes a value at runtime (tests / debug menu).
  void set(String key, Object value) => _values[key] = value;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> refresh() async => false;

  Object? _raw(String key) => _values[key];

  @override
  int getInt(String key) => switch (_raw(key)) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v) ?? 0,
    _ => 0,
  };

  @override
  double getDouble(String key) => switch (_raw(key)) {
    final num v => v.toDouble(),
    final String v => double.tryParse(v) ?? 0,
    _ => 0,
  };

  @override
  bool getBool(String key) => switch (_raw(key)) {
    final bool v => v,
    final String v => v == 'true',
    _ => false,
  };

  @override
  String getString(String key) => _raw(key)?.toString() ?? '';
}
