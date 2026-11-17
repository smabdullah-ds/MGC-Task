import 'package:bazaar_sort/core/economy/player_state.dart';

/// Upgrades raw save JSON from any older schema to
/// [PlayerState.schemaVersion]. Each step is a pure function from version
/// N to N + 1, so old saves replay every step in order.
///
/// History:
/// * v1 (pre-release): `level` (next level), `coins`, `stars` as a list of
///   `[level, stars]` pairs, settings flattened at the top level.
/// * v2: current shape (see [PlayerState.toJson]).
abstract final class SaveMigrations {
  static final Map<int, Map<String, Object?> Function(Map<String, Object?>)>
  _steps = {1: _v1ToV2};

  /// Migrates [json]. Saves without a version are treated as v1. Saves from a
  /// *newer* app version are returned unchanged (fields this version doesn't
  /// know are ignored when decoding).
  static Map<String, Object?> migrate(Map<String, Object?> json) {
    var data = Map<String, Object?>.of(json);
    var version = data['v'] as int? ?? 1;
    while (version < PlayerState.schemaVersion) {
      final step = _steps[version];
      if (step == null) {
        throw StateError('no migration from save version $version');
      }
      data = step(data)..['v'] = version + 1;
      version++;
    }
    return data;
  }

  /// Decodes any supported save into a [PlayerState].
  static PlayerState load(Map<String, Object?> json) =>
      PlayerState.fromJson(migrate(json));

  static Map<String, Object?> _v1ToV2(Map<String, Object?> v1) {
    final stars = <String, Object?>{
      for (final pair in (v1['stars'] as List<Object?>?) ?? const <Object?>[])
        if (pair case [final Object level, final Object stars]) '$level': stars,
    };
    return {
      'nextLevel': v1['level'] ?? 1,
      'coins': v1['coins'] ?? 0,
      'stars': stars,
      'settings': {
        'sound': v1['sound'] ?? true,
        'music': v1['music'] ?? true,
        'haptics': v1['haptics'] ?? true,
      },
    };
  }
}
