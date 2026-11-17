/// Typed access to remotely tunable values.
///
/// Implementations must always return a value: the live remote value when
/// available, otherwise the local default from `remote_config_defaults.dart`.
abstract interface class RemoteConfigService {
  /// Applies defaults and starts a non-blocking fetch.
  Future<void> initialize();

  /// Fetches and activates the latest values. Returns `true` if values changed.
  Future<bool> refresh();

  /// Reads an int.
  int getInt(String key);

  /// Reads a double.
  double getDouble(String key);

  /// Reads a bool.
  bool getBool(String key);

  /// Reads a string.
  String getString(String key);
}
