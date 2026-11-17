import 'dart:convert';

import 'package:bazaar_sort/services/storage/storage_service.dart';

/// Non-persistent storage for tests and previews.
///
/// Values are round-tripped through JSON so tests catch values that would
/// not survive real persistence.
class MemoryStorageService implements StorageService {
  final Map<String, String> _data = <String, String>{};

  /// Number of completed writes (tests use it to assert save points).
  int writeCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Map<String, Object?>? read(String key) {
    final raw = _data[key];
    if (raw == null) return null;
    return (jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>();
  }

  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    _data[key] = jsonEncode(value);
    writeCount++;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}
