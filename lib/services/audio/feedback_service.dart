import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

/// Sound effects. The enum name is the file name in `assets/audio/`.
enum Sfx {
  tap,
  pick,
  drop,
  invalid,
  complete,
  win,
  coin,
  booster,
  button,
  restore,
}

/// Haptic strengths.
enum Haptic { selection, light, medium }

/// Sound, music and haptics. Every call is a no-op when its setting is off.
abstract interface class FeedbackService {
  /// Preloads audio.
  Future<void> initialize();

  /// Applies the player's toggles.
  void configure({
    required bool sound,
    required bool music,
    required bool haptics,
  });

  /// Plays a sound effect.
  void play(Sfx sfx);

  /// Fires a haptic.
  void haptic(Haptic kind);

  /// Pauses music (app backgrounded, ad showing).
  void pauseMusic();

  /// Resumes music if enabled.
  void resumeMusic();
}

/// [FeedbackService] with flame_audio and Flutter haptics.
class FlameFeedbackService implements FeedbackService {
  static const String _musicFile = 'music_bazaar.mp3';

  bool _sound = true;
  bool _music = true;
  bool _haptics = true;
  bool _musicPlaying = false;
  bool _ready = false;

  @override
  Future<void> initialize() async {
    try {
      await FlameAudio.audioCache.loadAll([
        for (final s in Sfx.values) '${s.name}.mp3',
        _musicFile,
      ]);
      await FlameAudio.bgm.initialize();
      _ready = true;
    } on Object {
      // Audio is optional; the game must run silently if it fails.
      _ready = false;
    }
  }

  @override
  void configure({
    required bool sound,
    required bool music,
    required bool haptics,
  }) {
    _sound = sound;
    _haptics = haptics;
    if (music != _music || !_musicPlaying) {
      _music = music;
      music ? resumeMusic() : pauseMusic();
    }
  }

  @override
  void play(Sfx sfx) {
    if (!_sound || !_ready) return;
    unawaited(
      FlameAudio.play(
        '${sfx.name}.mp3',
        volume: 0.7,
      ).then<void>((_) {}, onError: (Object _) {}),
    );
  }

  @override
  void haptic(Haptic kind) {
    if (!_haptics) return;
    unawaited(switch (kind) {
      Haptic.selection => HapticFeedback.selectionClick(),
      Haptic.light => HapticFeedback.lightImpact(),
      Haptic.medium => HapticFeedback.mediumImpact(),
    });
  }

  @override
  void pauseMusic() {
    if (!_ready || !_musicPlaying) return;
    unawaited(FlameAudio.bgm.pause());
    _musicPlaying = false;
  }

  @override
  void resumeMusic() {
    if (!_ready || !_music || _musicPlaying) return;
    _musicPlaying = true;
    unawaited(
      (FlameAudio.bgm.isPlaying
              ? FlameAudio.bgm.resume()
              : FlameAudio.bgm.play(_musicFile, volume: 0.35))
          .then<void>((_) {}, onError: (Object _) => _musicPlaying = false),
    );
  }
}

/// Silent implementation for tests; records calls.
class FakeFeedbackService implements FeedbackService {
  /// Sound effects played.
  final List<Sfx> played = [];

  /// Haptics fired.
  final List<Haptic> haptics = [];

  bool _sound = true;
  bool _haptics = true;

  /// Whether music would be playing.
  bool musicOn = false;

  @override
  Future<void> initialize() async {}

  @override
  void configure({
    required bool sound,
    required bool music,
    required bool haptics,
  }) {
    _sound = sound;
    _haptics = haptics;
    musicOn = music;
  }

  @override
  void play(Sfx sfx) {
    if (_sound) played.add(sfx);
  }

  @override
  void haptic(Haptic kind) {
    if (_haptics) haptics.add(kind);
  }

  @override
  void pauseMusic() => musicOn = false;

  @override
  void resumeMusic() => musicOn = true;
}
