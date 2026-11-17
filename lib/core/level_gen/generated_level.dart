import 'package:bazaar_sort/core/game_logic/board_state.dart';
import 'package:bazaar_sort/core/game_logic/move.dart';
import 'package:bazaar_sort/core/level_gen/difficulty_curve.dart';

/// A ready-to-play level, as stored in `assets/levels/*.json`.
final class GeneratedLevel {
  /// Creates a level.
  const new({
    required this.level,
    required this.seed,
    required this.spec,
    required this.board,
    required this.optimalMoves,
    required this.provenOptimal,
    this.solution = const <Move>[],
    this.moveLimit,
  });

  /// Decodes an entry of a level file.
  factory fromJson(Map<String, Object?> json) {
    final level = json['n']! as int;
    final tags = [for (final t in json['tags']! as List<Object?>) t! as String];
    final board = BoardState.fromJson(
      (json['board']! as Map<Object?, Object?>).cast<String, Object?>(),
    );
    final kind = LevelKind.values.byName(tags.first);
    return GeneratedLevel(
      level: level,
      seed: json['seed']! as int,
      board: board,
      optimalMoves: json['opt']! as int,
      provenOptimal: json['proven'] as bool? ?? false,
      moveLimit: json['limit'] as int?,
      solution: decodeMoves(json['sol'] as String? ?? ''),
      spec: LevelSpec(
        level: level,
        kind: kind,
        itemTypes: board.itemTypes.length,
        capacity: board.capacity,
        emptyShelves: board.shelves.where((s) => s.isEmpty).length,
        minOptimalMoves: 0,
        hiddenItems: tags.contains('hidden') ? 1 : 0,
        lockedShelves: tags.contains('locked') ? 1 : 0,
        frozenItems: tags.contains('frozen') ? 1 : 0,
        moveLimitFactor: json['limit'] == null ? null : 1,
      ),
    );
  }

  /// 1-based level number.
  final int level;

  /// Seed it was generated from.
  final int seed;

  /// Spec it was generated for (after any relaxation).
  final LevelSpec spec;

  /// Starting board.
  final BoardState board;

  /// Solver move count (optimal when [provenOptimal]).
  final int optimalMoves;

  /// Whether [optimalMoves] is proven minimal.
  final bool provenOptimal;

  /// Solver's solution from the start board. Stored so tests can replay it
  /// as a proof of solvability; live hints are recomputed from the current
  /// board.
  final List<Move> solution;

  /// Move limit for move-limited levels.
  final int? moveLimit;

  /// Pacing role.
  LevelKind get kind => spec.kind;

  /// Whether this is a boss level (coin bonus).
  bool get isBoss => spec.kind == LevelKind.boss;

  /// Tags such as `hard`, `hidden`, `move_limit`.
  List<String> get tags => spec.tags;

  /// JSON entry for level files.
  Map<String, Object?> toJson() => <String, Object?>{
    'n': level,
    'seed': seed,
    'opt': optimalMoves,
    'proven': provenOptimal,
    if (moveLimit != null) 'limit': moveLimit,
    'tags': tags,
    'board': board.toJson(),
    'sol': encodeMoves(solution),
  };

  /// Encodes moves as base-36 digit pairs, e.g. `"0a2b"` = 0→10, 2→11.
  static String encodeMoves(List<Move> moves) => moves
      .map((m) => '${m.from.toRadixString(36)}${m.to.toRadixString(36)}')
      .join();

  /// Inverse of [encodeMoves].
  static List<Move> decodeMoves(String encoded) => [
    for (var i = 0; i + 1 < encoded.length; i += 2)
      Move(
        int.parse(encoded[i], radix: 36),
        int.parse(encoded[i + 1], radix: 36),
      ),
  ];
}
