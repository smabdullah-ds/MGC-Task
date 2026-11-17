/// Durable key → JSON storage.
///
/// Writes must be atomic per key: after a crash a key holds either the old
/// or the new value, never a mix. The save game is stored as a single key so
/// a whole save is atomic.
abstract interface class StorageService {
  /// Opens the underlying store.
  Future<void> initialize();

  /// Reads the JSON map stored under [key], or `null`.
  Map<String, Object?>? read(String key);

  /// Writes [value] under [key] and flushes it to disk.
  Future<void> write(String key, Map<String, Object?> value);

  /// Removes [key].
  Future<void> delete(String key);
}
