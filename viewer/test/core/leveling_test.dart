import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/core/leveling.dart';

void main() {
  group('thresholdForLevel', () {
    test('progressão inicial', () {
      expect(thresholdForLevel(1), 50);
      expect(thresholdForLevel(2), 60);
      expect(thresholdForLevel(3), 72);
      expect(thresholdForLevel(4), 87);
    });

    test('level < 1', () {
      expect(() => thresholdForLevel(0), throwsArgumentError);
    });
  });

  group('computeLevelFromTotalPoints', () {
    test('casos alinhados a tests/test_leveling.py', () {
      void check(int total, int expLevel, int expLp, int expNext) {
        final r = computeLevelFromTotalPoints(total);
        expect(r.level, expLevel, reason: 'total=$total level');
        expect(r.levelPoints, expLp, reason: 'total=$total levelPoints');
        expect(r.nextThreshold, expNext, reason: 'total=$total next');
      }

      check(0, 1, 0, 50);
      check(49, 1, 49, 50);
      check(50, 2, 0, 60);
      check(59, 2, 9, 60);
      check(60, 2, 10, 60);
      check(71, 2, 21, 60);
      check(72, 2, 22, 60);
      check(110, 3, 0, 72);
      check(111, 3, 1, 72);
    });
  });

  group('levelProgressFromUserPointsMap', () {
    test('só points (API antiga)', () {
      final r = levelProgressFromUserPointsMap({'points': 2});
      expect(r.level, 1);
      expect(r.levelPoints, 2);
      expect(r.nextThreshold, 50);
    });

    test('points como double', () {
      final r = levelProgressFromUserPointsMap({'points': 2.0});
      expect(r.levelPoints, 2);
      expect(r.nextThreshold, 50);
    });
  });
}
