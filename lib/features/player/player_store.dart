import 'dart:async';

import 'package:bazaar_sort/core/economy/player_state.dart';
import 'package:bazaar_sort/core/economy/save_migrations.dart';
import 'package:bazaar_sort/services/service_providers.dart';
import 'package:bazaar_sort/services/storage/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Storage key of the save game.
const String saveKey = 'player';

/// Holds the [PlayerState] and persists every change.
///
/// All mutations go through [update], which applies a pure transition and
/// writes the whole state as one JSON document before notifying listeners
/// that depend on durability (win screens, purchases).
class PlayerStore extends Notifier<PlayerState> {
  StorageService get _storage => ref.read(storageServiceProvider);

  Future<void> _pending = Future<void>.value();

  @override
  PlayerState build() {
    final raw = _storage.read(saveKey);
    if (raw == null) {
      return PlayerState(installedAt: DateTime.now());
    }
    try {
      return SaveMigrations.load(raw);
    } on Object catch (e, st) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .recordError(e, st, reason: 'save_decode'),
      );
      return PlayerState(installedAt: DateTime.now());
    }
  }

  /// Current state, readable outside the notifier.
  PlayerState get current => state;

  /// Applies [change] and saves. Returns the new state, or `null` if
  /// [change] returned `null` (e.g. not enough coins), in which case nothing
  /// is saved.
  Future<PlayerState?> update(PlayerState? Function(PlayerState) change) {
    final next = change(state);
    if (next == null) return Future.value();
    state = next;
    return _save(next).then((_) => next);
  }

  /// Writes are serialized so a slow write can never overwrite a newer one.
  Future<void> _save(PlayerState s) {
    return _pending = _pending.then((_) => _storage.write(saveKey, s.toJson()));
  }

  /// Completes when every queued write has hit storage.
  Future<void> flush() => _pending;
}

/// The player.
final playerProvider = NotifierProvider<PlayerStore, PlayerState>(
  PlayerStore.new,
);
