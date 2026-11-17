import 'package:bazaar_sort/core/level_gen/difficulty_curve.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const curve = DifficultyCurve();

  test('levels 1–10 are a tutorial ramp with K from 2 to 4', () {
    final ks = [for (var l = 1; l <= 10; l++) curve.specFor(l).itemTypes];
    expect(ks.first, 2);
    expect(ks.last, 4);
    expect(ks.every((k) => k >= 2 && k <= 4), isTrue);
    for (var i = 1; i < ks.length; i++) {
      expect(ks[i], greaterThanOrEqualTo(ks[i - 1]));
    }
    expect(curve.kindOf(10), LevelKind.tutorial);
  });

  test('saw-tooth: hard every 5th, breather after, boss every 10th', () {
    expect(curve.kindOf(15), LevelKind.hard);
    expect(curve.kindOf(16), LevelKind.breather);
    expect(curve.kindOf(20), LevelKind.boss);
    expect(curve.kindOf(21), LevelKind.breather);
    expect(curve.kindOf(17), LevelKind.normal);
    final hard = curve.specFor(45);
    final breather = curve.specFor(46);
    final normal = curve.specFor(47);
    expect(hard.itemTypes, greaterThan(breather.itemTypes));
    expect(normal.itemTypes, greaterThanOrEqualTo(breather.itemTypes));
  });

  test('K grows over time and stays capped', () {
    expect(
      curve.specFor(300).itemTypes,
      greaterThan(curve.specFor(12).itemTypes),
    );
    for (var l = 1; l <= 1200; l++) {
      final s = curve.specFor(l);
      expect(s.itemTypes, inInclusiveRange(2, 11));
      expect(s.emptyShelves, inInclusiveRange(1, 2));
      expect(s.shelves, s.itemTypes + s.emptyShelves);
    }
  });

  test('hard levels late in the game use one empty shelf', () {
    final s = curve.specFor(155);
    expect(s.kind, LevelKind.hard);
    expect(s.emptyShelves, 1);
    expect(s.itemTypes, lessThanOrEqualTo(7));
  });

  test('obstacles never appear before their intro level', () {
    for (var l = 1; l < 20; l++) {
      expect(curve.specFor(l).hiddenItems, 0);
    }
    for (var l = 1; l < 40; l++) {
      expect(curve.specFor(l).lockedShelves, 0);
    }
    for (var l = 1; l < 60; l++) {
      expect(curve.specFor(l).frozenItems, 0);
    }
    for (var l = 1; l < 80; l++) {
      expect(curve.specFor(l).moveLimitFactor, isNull);
    }
  });

  test('each obstacle is introduced alone', () {
    expect(curve.specFor(20).tags, ['boss', 'hidden']);
    expect(curve.specFor(40).tags, ['boss', 'locked']);
    expect(curve.specFor(60).tags, ['boss', 'frozen']);
    expect(curve.specFor(80).tags, ['boss', 'move_limit']);
  });

  test('obstacles recur after introduction', () {
    final later = [for (var l = 81; l <= 140; l++) curve.specFor(l)];
    expect(later.where((s) => s.hiddenItems > 0), isNotEmpty);
    expect(later.where((s) => s.lockedShelves > 0), isNotEmpty);
    expect(later.where((s) => s.frozenItems > 0), isNotEmpty);
    expect(later.where((s) => s.moveLimitFactor != null), isNotEmpty);
  });

  group('remote overrides', () {
    test('json overrides fields and keeps the rest', () {
      final c = DifficultyCurveConfig.fromJson(
        '{"maxTypes": 6, "hardEvery": 4, "tutorialTypes": [3, 3], '
        '"moveLimitFactor": 2.0}',
      );
      expect(c.maxTypes, 6);
      expect(c.hardEvery, 4);
      expect(c.tutorialTypes, [3, 3]);
      expect(c.moveLimitFactor, 2.0);
      expect(c.capacity, 4);
      final custom = DifficultyCurve(c);
      expect(custom.specFor(5).itemTypes, 3, reason: 'last value repeats');
      expect(custom.specFor(500).itemTypes, lessThanOrEqualTo(7));
    });

    test('empty or malformed json uses defaults', () {
      expect(DifficultyCurveConfig.fromJson('').maxTypes, 10);
      expect(DifficultyCurveConfig.fromJson('{oops').maxTypes, 10);
      expect(DifficultyCurveConfig.fromJson('[1]').maxTypes, 10);
    });
  });
}
