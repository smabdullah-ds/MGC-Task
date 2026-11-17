// Pre-generates and validates the bundled levels.
//
//   dart run tool/generate_levels.dart                 # levels 1–1000
//   dart run tool/generate_levels.dart --from 1 --to 200 --workers 4
//   dart run tool/generate_levels.dart --check          # verify files only
//
// Output: assets/levels/levels_0001_0100.json, levels_0101_0200.json, …
// Each entry stores the seed, board, optimal move count and difficulty tags.
// The run ends with a summary of the difficulty distribution.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:bazaar_sort/core/game_logic/game_rules.dart';
import 'package:bazaar_sort/core/level_gen/generated_level.dart';
import 'package:bazaar_sort/core/level_gen/level_generator.dart';
import 'package:bazaar_sort/core/level_gen/level_validation.dart';

const int _perFile = 100;

Future<void> main(List<String> args) async {
  final opts = _parse(args);
  final from = opts['from'] ?? 1;
  final to = opts['to'] ?? 1000;
  final workers = opts['workers'] ?? Platform.numberOfProcessors;
  final outDir = Directory('assets/levels')..createSync(recursive: true);

  if (args.contains('--check')) {
    exit(_check(outDir) ? 0 : 1);
  }

  final sw = Stopwatch()..start();
  final firstFile = (from - 1) ~/ _perFile;
  final lastFile = (to - 1) ~/ _perFile;
  final all = <GeneratedLevel>[];

  for (var f = firstFile; f <= lastFile; f++) {
    final start = math.max(from, f * _perFile + 1);
    final end = math.min(to, (f + 1) * _perFile);
    final levels = await _generateRange(start, end, workers);
    all.addAll(levels);
    final file = File('${outDir.path}/${fileNameFor(f * _perFile + 1)}')
      ..writeAsStringSync(
        jsonEncode({
          'version': 1,
          'levels': [for (final l in levels) l.toJson()],
        }),
      );
    stdout.writeln(
      'wrote ${file.path} ($start–$end) '
      '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
    );
  }
  _summary(all);
}

/// File holding [level] (1-based).
String fileNameFor(int level) {
  final first = ((level - 1) ~/ _perFile) * _perFile + 1;
  final last = first + _perFile - 1;
  String p(int v) => v.toString().padLeft(4, '0');
  return 'levels_${p(first)}_${p(last)}.json';
}

Future<List<GeneratedLevel>> _generateRange(
  int start,
  int end,
  int workers,
) async {
  final levels = [for (var l = start; l <= end; l++) l];
  final buckets = List.generate(workers, (_) => <int>[]);
  for (var i = 0; i < levels.length; i++) {
    buckets[i % workers].add(levels[i]);
  }
  final results = await Future.wait([
    for (final b in buckets.where((b) => b.isNotEmpty))
      Isolate.run(() {
        const gen = LevelGenerator();
        return [for (final l in b) jsonEncode(gen.generate(l).toJson())];
      }),
  ]);
  final out = [
    for (final r in results)
      for (final j in r)
        GeneratedLevel.fromJson(
          (jsonDecode(j) as Map<Object?, Object?>).cast<String, Object?>(),
        ),
  ]..sort((a, b) => a.level.compareTo(b.level));
  return out;
}

bool _check(Directory dir) {
  var ok = true;
  var count = 0;
  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;
    final data = (jsonDecode(file.readAsStringSync()) as Map<Object?, Object?>)
        .cast<String, Object?>();
    for (final raw in data['levels']! as List<Object?>) {
      final level = GeneratedLevel.fromJson(
        (raw! as Map<Object?, Object?>).cast<String, Object?>(),
      );
      count++;
      if (!replaySolves(level) || GameRules.standard.isWon(level.board)) {
        ok = false;
        stderr.writeln('level ${level.level} FAILED');
      }
    }
  }
  stdout.writeln('checked $count levels: ${ok ? 'all solvable' : 'FAILURES'}');
  return ok;
}

void _summary(List<GeneratedLevel> levels) {
  if (levels.isEmpty) return;
  final byKind = <String, int>{};
  final byTag = <String, int>{};
  final byK = <int, int>{};
  var proven = 0;
  for (final l in levels) {
    byKind.update(l.kind.name, (v) => v + 1, ifAbsent: () => 1);
    for (final t in l.tags.skip(1)) {
      byTag.update(t, (v) => v + 1, ifAbsent: () => 1);
    }
    byK.update(l.spec.itemTypes, (v) => v + 1, ifAbsent: () => 1);
    if (l.provenOptimal) proven++;
  }
  stdout
    ..writeln('\n=== Difficulty distribution (${levels.length} levels) ===')
    ..writeln('Kinds:     $byKind')
    ..writeln('Obstacles: $byTag')
    ..writeln(
      'Item types (K): ${Map.fromEntries(byK.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))}',
    )
    ..writeln(
      'Proven optimal: $proven/${levels.length} '
      '(${(proven * 100 / levels.length).toStringAsFixed(1)}%)',
    );
  for (var b = 0; b < levels.length; b += 100) {
    final slice = levels.skip(b).take(100).toList();
    final moves = slice.map((l) => l.optimalMoves).toList()..sort();
    final avg = moves.reduce((a, c) => a + c) / moves.length;
    stdout.writeln(
      'Levels ${slice.first.level.toString().padLeft(4)}–'
      '${slice.last.level.toString().padLeft(4)}: optimal moves '
      'min ${moves.first}, median ${moves[moves.length ~/ 2]}, '
      'max ${moves.last}, avg ${avg.toStringAsFixed(1)}',
    );
  }
}

Map<String, int> _parse(List<String> args) {
  final out = <String, int>{};
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i].startsWith('--')) {
      final v = int.tryParse(args[i + 1]);
      if (v != null) out[args[i].substring(2)] = v;
    }
  }
  return out;
}
