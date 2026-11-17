import 'dart:convert';
import 'dart:io';

import 'package:bazaar_sort/core/game_logic/game_rules.dart';
import 'package:bazaar_sort/core/level_gen/generated_level.dart';
import 'package:bazaar_sort/core/level_gen/level_generator.dart';
import 'package:bazaar_sort/core/level_gen/level_validation.dart';
import 'package:flutter_test/flutter_test.dart';

List<GeneratedLevel> _loadAll() {
  final files =
      Directory('assets/levels')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      for (final raw
          in (jsonDecode(f.readAsStringSync())
                  as Map<String, Object?>)['levels']!
              as List<Object?>)
        GeneratedLevel.fromJson(
          (raw! as Map<Object?, Object?>).cast<String, Object?>(),
        ),
  ];
}

void main() {
  final levels = _loadAll();

  test('levels 1–1000 are bundled, in order, once each', () {
    expect(levels, hasLength(1000));
    for (var i = 0; i < levels.length; i++) {
      expect(levels[i].level, i + 1);
    }
  });

  test(
    'every bundled level is solvable (stored solution replays to a win)',
    () {
      final failures = [
        for (final l in levels)
          if (!replaySolves(l)) l.level,
      ];
      expect(failures, isEmpty);
    },
  );

  test('no bundled level starts won or with a completed shelf', () {
    for (final l in levels) {
      expect(GameRules.standard.isWon(l.board), isFalse, reason: '${l.level}');
      expect(l.board.completedCount, 0, reason: '${l.level}');
    }
  });

  test('bundled files match the generator (sampled)', () {
    const gen = LevelGenerator();
    for (final n in [1, 10, 37, 120, 333]) {
      expect(gen.generate(n).board, levels[n - 1].board, reason: 'level $n');
    }
  });
}
