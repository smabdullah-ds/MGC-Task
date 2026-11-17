// Fails (exit code 1) when line coverage of files under a path prefix is
// below a threshold.
//
// Usage: dart run tool/check_coverage.dart coverage/lcov.info lib/core 80
import 'dart:io';

void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln('usage: check_coverage <lcov.info> <path-prefix> <min%>');
    exit(64);
  }
  final lcov = File(args[0]);
  final prefix = args[1];
  final minPercent = double.parse(args[2]);
  if (!lcov.existsSync()) {
    stderr.writeln('No coverage file at ${lcov.path}');
    exit(1);
  }

  var found = 0;
  var hit = 0;
  var inScope = false;
  final perFile = <String, (int, int)>{};
  String? current;
  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll(r'\', '/');
      inScope = current.contains(prefix);
    } else if (inScope && line.startsWith('LF:')) {
      final lf = int.parse(line.substring(3));
      found += lf;
      perFile[current!] = (lf, perFile[current]?.$2 ?? 0);
    } else if (inScope && line.startsWith('LH:')) {
      final lh = int.parse(line.substring(3));
      hit += lh;
      perFile[current!] = (perFile[current]?.$1 ?? 0, lh);
    }
  }

  if (found == 0) {
    stdout.writeln('No instrumented lines under $prefix; nothing to check.');
    return;
  }
  final percent = hit * 100 / found;
  for (final MapEntry(key: file, value: (lf, lh)) in perFile.entries) {
    final p = lf == 0 ? 100 : lh * 100 / lf;
    stdout.writeln('${p.toStringAsFixed(1).padLeft(6)}%  $file');
  }
  stdout.writeln(
    'Coverage of $prefix: ${percent.toStringAsFixed(1)}% '
    '($hit/$found lines), minimum $minPercent%',
  );
  if (percent < minPercent) exit(1);
}
