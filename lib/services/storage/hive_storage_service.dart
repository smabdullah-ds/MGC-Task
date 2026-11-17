import 'dart:convert';

import 'package:bazaar_sort/config/constants.dart';
import 'package:bazaar_sort/services/storage/storage_service.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// [StorageService] on a Hive box of JSON strings.
///
/// Hive appends each `put` as a checksummed frame and drops a torn final
/// frame on the next open, so a write is atomic: after a crash or a kill
/// the key holds either the previous or the new value. As a second line of
/// defence the previous value of every key is kept under `<key>.bak` and
/// used if the current value ever fails to decode.
class HiveStorageService implements StorageService {
  /// Creates the service. [boxName] is overridable for tests.
  new({this.boxName = AppConstants.saveBoxName});

  /// Name of the Hive box.
  final String boxName;

  Box<String>? _box;

  Box<String> get _open {
    final box = _box;
    if (box == null) throw StateError('HiveStorageService not initialized');
    return box;
  }

  @override
  Future<void> initialize() async {
    if (_box != null) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(boxName);
  }

  @override
  Map<String, Object?>? read(String key) =>
      _decode(_open.get(key)) ?? _decode(_open.get('$key.bak'));

  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    final box = _open;
    final previous = box.get(key);
    await box.putAll({
      if (previous != null && _decode(previous) != null) '$key.bak': previous,
      key: jsonEncode(value),
    });
    await box.flush();
  }

  @override
  Future<void> delete(String key) async {
    await _open.deleteAll(<String>[key, '$key.bak']);
    await _open.flush();
  }

  static Map<String, Object?>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>();
    } on Object {
      return null;
    }
  }
}
