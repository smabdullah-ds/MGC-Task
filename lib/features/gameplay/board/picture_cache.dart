import 'dart:collection';
import 'dart:ui';

/// Small LRU cache of recorded [Picture]s.
///
/// Vector art is re-recorded only when its inputs (item, size, colourblind
/// mode) change; each frame then just replays cached pictures. This keeps the
/// board well inside the frame budget on low-end (2 GB) Android devices and
/// avoids per-frame Paint/Path allocations.
class PictureCache {
  /// Creates a cache holding at most [capacity] pictures.
  new({this.capacity = 256});

  /// Maximum entries.
  final int capacity;

  final LinkedHashMap<String, Picture> _entries = LinkedHashMap();

  /// Hits so far (diagnostics, tests).
  int hits = 0;

  /// Misses so far (diagnostics, tests).
  int misses = 0;

  /// Returns the picture for [key], recording it with [draw] on a miss.
  Picture get(String key, Size size, void Function(Canvas canvas) draw) {
    final cached = _entries.remove(key);
    if (cached != null) {
      hits++;
      _entries[key] = cached; // move to most-recent
      return cached;
    }
    misses++;
    final recorder = PictureRecorder();
    draw(Canvas(recorder, Offset.zero & size));
    final picture = recorder.endRecording();
    _entries[key] = picture;
    if (_entries.length > capacity) {
      _entries.remove(_entries.keys.first)?.dispose();
    }
    return picture;
  }

  /// Number of cached pictures.
  int get length => _entries.length;

  /// Drops everything.
  void clear() {
    for (final p in _entries.values) {
      p.dispose();
    }
    _entries.clear();
  }

  /// Shared cache for board art.
  static final PictureCache board = PictureCache();
}
