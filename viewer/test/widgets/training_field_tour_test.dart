import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/widgets/student/training_field_tour.dart';

// training_field_tour.dart: funções de persistência (SharedPreferences)
// e constantes de GlobalKey. Os widgets internos são complexos demais para
// testar isoladamente (overlay com GlobalKey renderizado ao vivo), então
// cobrimos apenas a lógica de persistência.

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('trainingFieldTourDone', () {
    test('retorna false quando nenhum tour foi marcado', () async {
      final done = await trainingFieldTourDone('user-1');
      expect(done, isFalse);
    });

    test('retorna false para usuário diferente do que foi marcado', () async {
      await markTrainingFieldTourDone('user-1');
      final done = await trainingFieldTourDone('user-2');
      expect(done, isFalse);
    });
  });

  group('markTrainingFieldTourDone', () {
    test('persiste tour como concluído', () async {
      await markTrainingFieldTourDone('user-1');
      final done = await trainingFieldTourDone('user-1');
      expect(done, isTrue);
    });

    test('funciona de forma independente para usuários diferentes', () async {
      await markTrainingFieldTourDone('user-A');
      expect(await trainingFieldTourDone('user-A'), isTrue);
      expect(await trainingFieldTourDone('user-B'), isFalse);
    });
  });

  group('GlobalKeys do tour', () {
    test('tourKeyHeader é uma GlobalKey', () {
      expect(tourKeyHeader, isA<GlobalKey>());
    });

    test('tourKeyStreak é uma GlobalKey distinta de tourKeyHeader', () {
      expect(tourKeyStreak, isNot(same(tourKeyHeader)));
    });

    test('tourKeyMissions é uma GlobalKey distinta', () {
      expect(tourKeyMissions, isNot(same(tourKeyStreak)));
    });

    test('tourKeyTrophies é uma GlobalKey distinta', () {
      expect(tourKeyTrophies, isNot(same(tourKeyMissions)));
    });
  });
}
