import 'dart:convert';
import 'dart:isolate';

import 'package:bazaar_sort/config/constants.dart';
import 'package:bazaar_sort/core/game_logic/board_state.dart';
import 'package:bazaar_sort/core/level_gen/difficulty_curve.dart';
import 'package:bazaar_sort/core/level_gen/generated_level.dart';
import 'package:bazaar_sort/core/level_gen/level_generator.dart';
import 'package:bazaar_sort/core/level_gen/solver.dart';
import 'package:bazaar_sort/services/remote_config/tuning.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Generates a level off the UI thread. Swappable in tests.
typedef LevelBuilder = Future<GeneratedLevel> Function(
  int level,
  int? seed,
  DifficultyCurve c,
);

/// Default builder: the shared generator in a background isolate.
Future<GeneratedLevel> isolateLevelBuilder(
  int level,
  int? seed,
  DifficultyCurve curve,
) =>
    Isolate.run(() => LevelGenerator(curve: curve).generate(level, seed: seed));

/// Solves in a background isolate with on-device hint limits.
Future<SolveResult> isolateSolve(BoardState board) =>
    Isolate.run(() => const Solver().solve(board, limits: SolverLimits.hint));

/// Loads levels: bundled JSON for 1–1000, on-device generation after that
/// (same code as the CLI, run in an isolate).
class LevelRepository {
  /// Creates a repository.
  new({
    required this.bundle,
    required this.curve,
    this.builder = isolateLevelBuilder,
  });

  /// Asset bundle with `assets/levels`.
  final AssetBundle bundle;

  /// Curve used beyond the bundled range.
  final DifficultyCurve curve;

  /// Generator used beyond the bundled range.
  final LevelBuilder builder;

  final Map<int, List<GeneratedLevel>> _files = {};
  final Map<int, GeneratedLevel> _generated = {};

  /// Asset path of the file holding [level].
  static String assetFor(int level) {
    const per = AppConstants.levelsPerFile;
    final first = ((level - 1) ~/ per) * per + 1;
    String p(int v) => v.toString().padLeft(4, '0');
    return 'assets/levels/levels_${p(first)}_${p(first + per - 1)}.json';
  }

  /// Loads [level] (1-based).
  Future<GeneratedLevel> load(int level) async {
    if (level <= AppConstants.bundledLevelCount) {
      final file = (level - 1) ~/ AppConstants.levelsPerFile;
      final levels = _files[file] ??= await _loadFile(level);
      return levels[(level - 1) % AppConstants.levelsPerFile];
    }
    return _generated[level] ??= await builder(level, null, curve);
  }

  /// Daily challenge for [day]: a level shaped like the player's current
  /// difficulty but seeded by the calendar date, identical for everyone.
  Future<GeneratedLevel> daily(DateTime day, {required int playerLevel}) {
    final seed = day.year * 10000 + day.month * 100 + day.day;
    final shapeLevel = (playerLevel.clamp(12, 400) ~/ 5) * 5 + 2;
    return builder(shapeLevel, seed, curve);
  }

  Future<List<GeneratedLevel>> _loadFile(int level) async {
    final raw = await bundle.loadString(assetFor(level));
    final data = (jsonDecode(raw) as Map<Object?, Object?>)
        .cast<String, Object?>();
    return [
      for (final l in data['levels']! as List<Object?>)
        GeneratedLevel.fromJson(
          (l! as Map<Object?, Object?>).cast<String, Object?>(),
        ),
    ];
  }
}

/// Level source.
final levelRepositoryProvider = Provider<LevelRepository>(
  (ref) => LevelRepository(
    bundle: rootBundle,
    curve: ref.watch(difficultyCurveProvider),
  ),
);

/// Background solver used for hints and dead-end detection.
final solveRunnerProvider = Provider<Future<SolveResult> Function(BoardState)>(
  (ref) => isolateSolve,
);
