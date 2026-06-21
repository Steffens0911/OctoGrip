import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/mission_today.dart';
import 'package:viewer/services/student_home_snapshot_store.dart';

// Testes para StudentHomeSnapshotStore: read, write e clearAll.

MissionWeek _week() => MissionWeek.fromJson({
      'monday': null,
      'tuesday': null,
      'wednesday': null,
      'thursday': null,
      'friday': null,
      'saturday': null,
      'sunday': null,
    });

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final store = StudentHomeSnapshotStore();

  group('StudentHomeSnapshotStore.read', () {
    test('retorna null quando não há snapshot salvo', () async {
      final result = await store.read(
        userId: 'u1',
        academyId: 'ac1',
        levelKey: 'beginner',
      );

      expect(result, isNull);
    });

    test('retorna null quando userId vazio', () async {
      final result = await store.read(
        userId: '',
        academyId: 'ac1',
        levelKey: 'beginner',
      );

      expect(result, isNull);
    });
  });

  group('StudentHomeSnapshotStore.write + read', () {
    test('persiste e recupera snapshot válido', () async {
      await store.write(
        userId: 'u1',
        academyId: 'ac1',
        levelKey: 'beginner',
        header: {'xp': 100, 'level': 2},
        week: _week(),
      );

      final snap = await store.read(
        userId: 'u1',
        academyId: 'ac1',
        levelKey: 'beginner',
      );

      expect(snap, isNotNull);
      expect(snap!.header['xp'], 100);
      expect(snap.savedAt, isNotNull);
    });

    test('retorna null quando academyId diferente', () async {
      await store.write(
        userId: 'u1',
        academyId: 'ac1',
        levelKey: 'beginner',
        header: {},
        week: _week(),
      );

      final snap = await store.read(
        userId: 'u1',
        academyId: 'ac2',
        levelKey: 'beginner',
      );

      expect(snap, isNull);
    });

    test('retorna null quando levelKey diferente', () async {
      await store.write(
        userId: 'u1',
        academyId: 'ac1',
        levelKey: 'beginner',
        header: {},
        week: _week(),
      );

      final snap = await store.read(
        userId: 'u1',
        academyId: 'ac1',
        levelKey: 'advanced',
      );

      expect(snap, isNull);
    });
  });

  group('StudentHomeSnapshotStore.clearAll', () {
    test('remove todos os snapshots', () async {
      await store.write(
        userId: 'u1',
        academyId: 'ac1',
        levelKey: 'beginner',
        header: {},
        week: _week(),
      );

      await StudentHomeSnapshotStore.clearAll();

      final snap = await store.read(
        userId: 'u1',
        academyId: 'ac1',
        levelKey: 'beginner',
      );

      expect(snap, isNull);
    });
  });
}
