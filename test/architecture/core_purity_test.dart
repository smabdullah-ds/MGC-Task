import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `core/` must stay pure Dart so it can run in isolates, the level CLI and
/// plain `dart test`.
void main() {
  test('lib/core has no Flutter or UI imports', () {
    final forbidden = RegExp(
      r'''^import\s+['"](package:flutter/|package:material_ui/|package:flame|dart:ui)''',
      multiLine: true,
    );
    final offenders = <String>[];
    for (final entity in Directory('lib/core').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        if (forbidden.hasMatch(entity.readAsStringSync())) {
          offenders.add(entity.path);
        }
      }
    }
    expect(offenders, isEmpty, reason: 'core/ must be pure Dart');
  });
}
