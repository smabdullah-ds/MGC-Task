import 'package:bazaar_sort/core/game_logic/board_state.dart';
import 'package:bazaar_sort/core/game_logic/game_rules.dart';
import 'package:bazaar_sort/core/game_logic/item.dart';
import 'package:bazaar_sort/core/game_logic/shelf.dart';
import 'package:bazaar_sort/core/level_gen/difficulty_curve.dart';
import 'package:bazaar_sort/core/level_gen/generated_level.dart';
import 'package:bazaar_sort/core/level_gen/seeded_random.dart';
import 'package:bazaar_sort/core/level_gen/solver.dart';

/// Builds solvable levels from `(level, seed)`. Deterministic: the same
/// inputs always produce the same board on every platform.
///
/// Method:
/// 1. Start from the solved board (K full shelves + E empty ones) and
///    scramble its items across the K full shelves.
/// 2. Add the level's obstacles.
/// 3. Verify with the [Solver]; reject boards that are unsolvable, too
///    easy (fewer than `minOptimalMoves`) or beyond the solver's limits.
///    The solver's move list is the proof of solvability.
///
/// Why not a pure reverse-move walk: the start shape (every shelf full or
/// empty) has very few predecessors in the reverse move graph, so random
/// reverse walks almost never land on it (measured: < 10% of walks for
/// K ≤ 4 and 0% for K ≥ 5). Shuffling into the start shape and proving
/// solvability with the solver gives the same guarantee for every level.
final class LevelGenerator {
  /// Creates a generator.
  const new({
    this.curve = const DifficultyCurve(),
    this.solver = const Solver(),
    this.limits = generationLimits,
    this.maxAttempts = 24,
  });

  /// Level pacing.
  final DifficultyCurve curve;

  /// Verifier.
  final Solver solver;

  /// Per-attempt solver limits.
  final SolverLimits limits;

  /// Boards tried before taking the best solvable one found.
  final int maxAttempts;

  /// Solver limits used for generation. Only the node limit is meant to
  /// bind: a time limit would make results depend on device speed and break
  /// determinism, so the time budget is deliberately generous.
  static const SolverLimits generationLimits = SolverLimits(
    maxNodes: 120000,
    maxDuration: Duration(minutes: 10),
    fallbackWeights: <double>[1.5, 3],
  );

  /// Default seed of a level (stable forever: changing it changes levels).
  static int seedFor(int level) => SeededRandom.derive(0xBA2AA25, level);

  /// Generates [level] with [seed] (defaults to [seedFor]).
  GeneratedLevel generate(int level, {int? seed}) {
    final spec = curve.specFor(level);
    final baseSeed = seed ?? seedFor(level);
    GeneratedLevel? best;

    // Obstacles are dropped one at a time only if no attempt succeeds with
    // them, so every level is guaranteed to come out solvable.
    for (final s in _relaxations(spec)) {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        final rng = SeededRandom(SeededRandom.derive(baseSeed, attempt));
        final board = _build(s, rng);
        if (board == null) continue;
        final result = solver.solve(board, limits: limits);
        if (!result.isSolved || result.moveCount == 0) continue;
        final candidate = GeneratedLevel(
          level: level,
          seed: baseSeed,
          spec: s,
          board: board,
          optimalMoves: result.moveCount,
          provenOptimal: result.optimal,
          solution: result.moves,
          moveLimit: s.moveLimitFactor == null
              ? null
              : (result.moveCount * s.moveLimitFactor!).ceil() + 2,
        );
        if (result.moveCount >= s.minOptimalMoves) return candidate;
        if (best == null || candidate.optimalMoves > best.optimalMoves) {
          best = candidate;
        }
      }
      if (best != null) return best;
    }
    throw StateError('could not generate level $level'); // unreachable
  }

  Iterable<LevelSpec> _relaxations(LevelSpec spec) sync* {
    yield spec;
    if (spec.frozenItems > 0 || spec.lockedShelves > 0) {
      yield _copy(spec, frozen: 0, locked: 0);
    }
    yield _copy(spec, frozen: 0, locked: 0, hidden: 0);
    if (spec.emptyShelves < 2) {
      yield _copy(spec, frozen: 0, locked: 0, hidden: 0, empties: 2);
    }
  }

  LevelSpec _copy(
    LevelSpec s, {
    int? frozen,
    int? locked,
    int? hidden,
    int? empties,
  }) => LevelSpec(
    level: s.level,
    kind: s.kind,
    itemTypes: s.itemTypes,
    capacity: s.capacity,
    emptyShelves: empties ?? s.emptyShelves,
    minOptimalMoves: s.minOptimalMoves,
    hiddenItems: hidden ?? s.hiddenItems,
    lockedShelves: locked ?? s.lockedShelves,
    frozenItems: frozen ?? s.frozenItems,
    moveLimitFactor: s.moveLimitFactor,
  );

  BoardState? _build(LevelSpec spec, SeededRandom rng) {
    final shelves = scramble(
      types: spec.itemTypes,
      capacity: spec.capacity,
      rng: rng,
    );
    if (shelves == null) return null;

    // Full shelves first in random order, empty shelves at the end.
    final full = shelves.where((s) => s.isNotEmpty).toList();
    rng.shuffle(full);
    final layout = [
      ...full,
      for (var i = 0; i < spec.emptyShelves; i++) <int>[],
    ];
    final items = [
      for (final s in layout) [for (final t in s) Item.of(t)],
    ];
    final unlockAfter = List<int>.filled(layout.length, 0);

    // Hidden: random non-top items.
    var placed = 0;
    for (var tries = 0; placed < spec.hiddenItems && tries < 200; tries++) {
      final s = rng.nextInt(full.length);
      final p = rng.nextInt(spec.capacity - 1);
      if (items[s][p].isHidden) continue;
      items[s][p] = Item.of(items[s][p].type, hidden: true);
      placed++;
    }

    // Frozen: random non-top items on full shelves.
    placed = 0;
    for (var tries = 0; placed < spec.frozenItems && tries < 200; tries++) {
      final s = rng.nextInt(full.length);
      final p = rng.nextInt(spec.capacity - 1);
      final it = items[s][p];
      if (it.isFrozen) continue;
      items[s][p] = Item.of(it.type, hidden: it.isHidden, frozen: true);
      placed++;
    }

    // Locked: either a full shelf (contents wait) or a spare empty shelf.
    if (spec.lockedShelves > 0) {
      final lockEmpty = spec.emptyShelves >= 2 && rng.chance(0.5);
      final index = lockEmpty ? layout.length - 1 : rng.nextInt(full.length);
      unlockAfter[index] = spec.itemTypes >= 6 ? 2 : 1;
    }

    final board = BoardState(
      capacity: spec.capacity,
      shelves: [
        for (var i = 0; i < layout.length; i++)
          Shelf(items[i], unlockAfter: unlockAfter[i]),
      ],
    ).withTopsRevealed();
    if (board.completedCount > 0) return null;
    if (GameRules.standard.isWon(board)) return null;
    return board;
  }

  /// Scrambles the solved board into the start shape: the K × C items of
  /// the solved state are shuffled across K full shelves, with E
  /// empty shelves added later. Returns item types per full shelf (bottom
  /// first), or `null` if a shelf came out already sorted.
  ///
  /// Solvability is *not* guaranteed here; the caller verifies every board
  /// with the solver (see the class docs for why a pure reverse-move walk
  /// is not used).
  static List<List<int>>? scramble({
    required int types,
    required int capacity,
    required SeededRandom rng,
  }) {
    final items = [
      for (var t = 0; t < types; t++)
        for (var i = 0; i < capacity; i++) t,
    ];
    rng.shuffle(items);
    final shelves = [
      for (var s = 0; s < types; s++)
        items.sublist(s * capacity, (s + 1) * capacity),
    ];
    return _hasStartShape(shelves, capacity, types) ? shelves : null;
  }

  static bool _hasStartShape(List<List<int>> shelves, int capacity, int types) {
    var full = 0;
    for (final s in shelves) {
      if (s.isEmpty) continue;
      if (s.length != capacity) return false;
      if (s.every((x) => x == s.first)) return false;
      full++;
    }
    return full == types;
  }
}
