import 'package:bazaar_sort/config/remote_config_defaults.dart';
import 'package:bazaar_sort/services/remote_config/remote_config_service.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// [RemoteConfigService] on Firebase Remote Config.
///
/// Defaults from `remote_config_defaults.dart` are set first, so every read
/// returns a sensible value offline or before the first fetch. A/B tests are
/// created in the Firebase console on these same keys (see KPI.md).
class FirebaseRemoteConfigService implements RemoteConfigService {
  final FirebaseRemoteConfig _rc = FirebaseRemoteConfig.instance;

  @override
  Future<void> initialize() async {
    await _rc.setDefaults(remoteConfigDefaults);
    await _rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 5)
            : const Duration(hours: 1),
      ),
    );
  }

  @override
  Future<bool> refresh() => _rc.fetchAndActivate();

  @override
  int getInt(String key) => _rc.getInt(key);

  @override
  double getDouble(String key) => _rc.getDouble(key);

  @override
  bool getBool(String key) => _rc.getBool(key);

  @override
  String getString(String key) => _rc.getString(key);
}
