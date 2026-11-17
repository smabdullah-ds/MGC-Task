import 'dart:convert';
import 'dart:math' as math;

/// Role of a level in the saw-tooth pacing.
enum LevelKind {
  /// Levels 1–10: teaches the basics.
  tutorial,

  /// Regular level.
  normal,

  /// Every 5th level: harder.
  hard,

  /// The level after a hard one: easier, to let players breathe.
  breather,

  /// Every 10th level: hard, with a coin bonus.
  boss,
}

/// Everything the generator needs to build one level.
final class LevelSpec {
  /// Creates a spec.
  const new({
    required this.level,
    required this.kind,
    required this.itemTypes,
    required this.capacity,
    required this.emptyShelves,
    required this.minOptimalMoves,
    this.hiddenItems = 0,
    this.lockedShelves = 0,
    this.frozenItems = 0,
    this.moveLimitFactor,
  });

  /// 1-based level number.
  final int level;

  /// Pacing role.
  final LevelKind kind;

  /// K: distinct item types (one full shelf each).
  final int itemTypes;

  /// C: items per shelf.
  final int capacity;

  /// E: empty shelves at the start.
  final int emptyShelves;

  /// Reject boards whose optimal solution is shorter than this.
  final int minOptimalMoves;

  /// Hidden ("?") items.
  final int hiddenItems;

  /// Shelves that start locked.
  final int lockedShelves;

  /// Frozen items.
  final int frozenItems;

  /// Move limit = optimal × factor (rounded up) when set.
  final double? moveLimitFactor;

  /// N: total shelves.
  int get shelves => itemTypes + emptyShelves;

  /// Tags written to the level file.
  List<String> get tags => [
    kind.name,
    if (hiddenItems > 0) 'hidden',
    if (lockedShelves > 0) 'locked',
    if (frozenItems > 0) 'frozen',
    if (moveLimitFactor != null) 'move_limit',
  ];
}

/// Tunable knobs of the difficulty curve. Every field can be overridden from
/// Remote Config with a JSON object (see [DifficultyCurveConfig.fromJson]).
final class DifficultyCurveConfig {
  /// Creates a config; defaults are the shipped curve.
  const new({
    this.capacity = 4,
    this.tutorialLevels = 10,
    this.tutorialTypes = const <int>[2, 2, 3, 3, 3, 4, 4, 4, 4, 4],
    this.startTypes = 4,
    this.maxTypes = 10,
    this.typesGrowthLevels = 250,
    this.typesGrowthExponent = 0.7,
    this.hardEvery = 5,
    this.bossEvery = 10,
    this.hardExtraTypes = 1,
    this.breatherFewerTypes = 1,
    this.emptyShelves = 2,
    this.oneEmptyFromLevel = 150,
    this.oneEmptyMaxTypes = 7,
    this.minMovesPerType = 1.6,
    this.hiddenFromLevel = 20,
    this.hiddenEvery = 2,
    this.lockedFromLevel = 40,
    this.lockedEvery = 3,
    this.frozenFromLevel = 60,
    this.frozenEvery = 3,
    this.moveLimitFromLevel = 80,
    this.moveLimitEvery = 4,
    this.moveLimitFactor = 1.5,
  });

  /// Parses overrides on top of the defaults. Unknown keys are ignored;
  /// malformed JSON falls back to the defaults.
  factory fromJson(String json) {
    if (json.trim().isEmpty) return const DifficultyCurveConfig();
    try {
      final m = (jsonDecode(json) as Map<Object?, Object?>)
          .cast<String, Object?>();
      const d = DifficultyCurveConfig();
      int i(String k, int v) => (m[k] as num?)?.toInt() ?? v;
      double f(String k, double v) => (m[k] as num?)?.toDouble() ?? v;
      final tt = m['tutorialTypes'];
      return DifficultyCurveConfig(
        capacity: i('capacity', d.capacity),
        tutorialLevels: i('tutorialLevels', d.tutorialLevels),
        tutorialTypes: tt is List
            ? [for (final v in tt) (v! as num).toInt()]
            : d.tutorialTypes,
        startTypes: i('startTypes', d.startTypes),
        maxTypes: i('maxTypes', d.maxTypes),
        typesGrowthLevels: i('typesGrowthLevels', d.typesGrowthLevels),
        typesGrowthExponent: f('typesGrowthExponent', d.typesGrowthExponent),
        hardEvery: i('hardEvery', d.hardEvery),
        bossEvery: i('bossEvery', d.bossEvery),
        hardExtraTypes: i('hardExtraTypes', d.hardExtraTypes),
        breatherFewerTypes: i('breatherFewerTypes', d.breatherFewerTypes),
        emptyShelves: i('emptyShelves', d.emptyShelves),
        oneEmptyFromLevel: i('oneEmptyFromLevel', d.oneEmptyFromLevel),
        oneEmptyMaxTypes: i('oneEmptyMaxTypes', d.oneEmptyMaxTypes),
        minMovesPerType: f('minMovesPerType', d.minMovesPerType),
        hiddenFromLevel: i('hiddenFromLevel', d.hiddenFromLevel),
        hiddenEvery: i('hiddenEvery', d.hiddenEvery),
        lockedFromLevel: i('lockedFromLevel', d.lockedFromLevel),
        lockedEvery: i('lockedEvery', d.lockedEvery),
        frozenFromLevel: i('frozenFromLevel', d.frozenFromLevel),
        frozenEvery: i('frozenEvery', d.frozenEvery),
        moveLimitFromLevel: i('moveLimitFromLevel', d.moveLimitFromLevel),
        moveLimitEvery: i('moveLimitEvery', d.moveLimitEvery),
        moveLimitFactor: f('moveLimitFactor', d.moveLimitFactor),
      );
    } on Object {
      return const DifficultyCurveConfig();
    }
  }

  /// C.
  final int capacity;

  /// Number of tutorial levels.
  final int tutorialLevels;

  /// K for each tutorial level (last value repeats if short).
  final List<int> tutorialTypes;

  /// K right after the tutorial.
  final int startTypes;

  /// K ceiling for normal levels.
  final int maxTypes;

  /// Levels after the tutorial over which K grows to [maxTypes].
  final int typesGrowthLevels;

  /// Shape of K growth: progress^exponent (< 1 front-loads growth).
  final double typesGrowthExponent;

  /// Every Nth level is hard.
  final int hardEvery;

  /// Every Nth level is a boss.
  final int bossEvery;

  /// Extra K on hard/boss levels.
  final int hardExtraTypes;

  /// Fewer K on breather levels.
  final int breatherFewerTypes;

  /// Default E.
  final int emptyShelves;

  /// Hard levels from here use one empty shelf.
  final int oneEmptyFromLevel;

  /// K cap on one-empty levels (keeps them fair).
  final int oneEmptyMaxTypes;

  /// Minimum optimal moves = K × this.
  final double minMovesPerType;

  /// First level with hidden items.
  final int hiddenFromLevel;

  /// Hidden items on every Nth level after that.
  final int hiddenEvery;

  /// First level with locked shelves.
  final int lockedFromLevel;

  /// Locked shelves on every Nth level after that.
  final int lockedEvery;

  /// First level with frozen items.
  final int frozenFromLevel;

  /// Frozen items on every Nth level after that.
  final int frozenEvery;

  /// First move-limited level.
  final int moveLimitFromLevel;

  /// Move limits on every Nth level after that.
  final int moveLimitEvery;

  /// Move limit = optimal × this.
  final double moveLimitFactor;
}

/// Maps a level number to a [LevelSpec].
///
/// Shape: a tutorial ramp, then K grows along a power curve with a
/// saw-tooth on top — every 5th level is hard (+K), the level after it is a
/// breather (−K), every 10th is a boss. Obstacles phase in from their first
/// level (20/40/60/80) on a rotating schedule, always on their own the first
/// time they appear so players learn one thing at a time.
final class DifficultyCurve {
  /// Creates a curve from [config].
  const new([this.config = const DifficultyCurveConfig()]);

  /// Tunable knobs.
  final DifficultyCurveConfig config;

  /// Pacing role of [level].
  LevelKind kindOf(int level) {
    final c = config;
    if (level <= c.tutorialLevels) return LevelKind.tutorial;
    if (level % c.bossEvery == 0) return LevelKind.boss;
    if (level % c.hardEvery == 0) return LevelKind.hard;
    if ((level - 1) % c.hardEvery == 0) return LevelKind.breather;
    return LevelKind.normal;
  }

  /// Spec for [level] (1-based).
  LevelSpec specFor(int level) {
    assert(level >= 1, 'levels are 1-based');
    final c = config;
    final kind = kindOf(level);

    if (kind == LevelKind.tutorial) {
      final types =
          c.tutorialTypes[math.min(level - 1, c.tutorialTypes.length - 1)];
      return LevelSpec(
        level: level,
        kind: kind,
        itemTypes: types,
        capacity: c.capacity,
        emptyShelves: c.emptyShelves,
        minOptimalMoves: math.max(2, types + level ~/ 3),
      );
    }

    final progress = math.min(
      1,
      (level - c.tutorialLevels) / c.typesGrowthLevels,
    );
    var types =
        (c.startTypes +
                (c.maxTypes - c.startTypes) *
                    math.pow(progress, c.typesGrowthExponent))
            .round();
    var empties = c.emptyShelves;
    var minMovesFactor = c.minMovesPerType;
    switch (kind) {
      case LevelKind.hard || LevelKind.boss:
        types += c.hardExtraTypes;
        minMovesFactor += 0.4;
        if (level >= c.oneEmptyFromLevel && kind == LevelKind.hard) {
          empties = 1;
          types = math.min(types, c.oneEmptyMaxTypes);
        }
      case LevelKind.breather:
        types -= c.breatherFewerTypes;
        minMovesFactor -= 0.4;
      case LevelKind.normal || LevelKind.tutorial:
        break;
    }
    types = types.clamp(2, c.maxTypes + c.hardExtraTypes);

    // On an obstacle's introduction level it appears alone.
    final intro = switch (level) {
      _ when level == c.hiddenFromLevel => 'hidden',
      _ when level == c.lockedFromLevel => 'locked',
      _ when level == c.frozenFromLevel => 'frozen',
      _ when level == c.moveLimitFromLevel => 'limit',
      _ => null,
    };
    bool on(String id, int from, int every, int phase) =>
        intro == null ? _rotating(level, from, every, phase) : intro == id;

    final hidden = on('hidden', c.hiddenFromLevel, c.hiddenEvery, 0)
        ? math.min(2 + (level - c.hiddenFromLevel) ~/ 40, types)
        : 0;
    final locked = on('locked', c.lockedFromLevel, c.lockedEvery, 1) ? 1 : 0;
    final frozen = on('frozen', c.frozenFromLevel, c.frozenEvery, 2)
        ? math.min(1 + (level - c.frozenFromLevel) ~/ 80, 3)
        : 0;
    final limited =
        on('limit', c.moveLimitFromLevel, c.moveLimitEvery, 3) &&
        kind != LevelKind.breather;

    return LevelSpec(
      level: level,
      kind: kind,
      itemTypes: types,
      capacity: c.capacity,
      emptyShelves: empties,
      minOptimalMoves: math.max(4, (types * minMovesFactor).round()),
      hiddenItems: hidden,
      lockedShelves: locked,
      frozenItems: frozen,
      moveLimitFactor: limited ? c.moveLimitFactor : null,
    );
  }

  /// After its introduction at [from], an obstacle appears on every
  /// [every]th level, offset by [phase] so obstacles don't always coincide.
  bool _rotating(int level, int from, int every, int phase) {
    if (level < from) return false;
    return (level + phase) % every == 0;
  }
}
