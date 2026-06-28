import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/punctuality_report.dart';

Map<String, dynamic> _entryJson({
  String id = 'u1',
  String name = 'João Silva',
  int streak = 5,
  int streakBest = 8,
  int punctual = 9,
  int late = 2,
  int total = 11,
  double pct = 81.8,
}) =>
    {
      'student_id': id,
      'name': name,
      'punctuality_streak': streak,
      'punctuality_streak_best': streakBest,
      'punctual_count': punctual,
      'late_count': late,
      'total_checkins': total,
      'punctuality_pct': pct,
    };

void main() {
  group('PunctualityStudentEntry.fromJson', () {
    test('desserializa todos os campos', () {
      final e = PunctualityStudentEntry.fromJson(_entryJson());

      expect(e.studentId, 'u1');
      expect(e.name, 'João Silva');
      expect(e.punctualityStreak, 5);
      expect(e.punctualityStreakBest, 8);
      expect(e.punctualCount, 9);
      expect(e.lateCount, 2);
      expect(e.totalCheckins, 11);
      expect(e.punctualityPct, closeTo(81.8, 0.01));
    });

    test('usa defaults quando campos opcionais ausentes', () {
      final e = PunctualityStudentEntry.fromJson({'student_id': 'u2'});

      expect(e.name, isNull);
      expect(e.punctualityStreak, 0);
      expect(e.punctualityStreakBest, 0);
      expect(e.punctualCount, 0);
      expect(e.lateCount, 0);
      expect(e.totalCheckins, 0);
      expect(e.punctualityPct, 0.0);
    });

    test('aceita punctuality_pct como inteiro (num)', () {
      final e = PunctualityStudentEntry.fromJson(
          {'student_id': 'u3', 'punctuality_pct': 75});
      expect(e.punctualityPct, closeTo(75.0, 0.01));
    });
  });

  group('PunctualityReport.fromJson', () {
    test('desserializa com lista de dois alunos', () {
      final r = PunctualityReport.fromJson({
        'academy_id': 'ac1',
        'days': 30,
        'students': [
          _entryJson(id: 'u1', pct: 80.0),
          _entryJson(id: 'u2', pct: 40.0),
        ],
      });

      expect(r.academyId, 'ac1');
      expect(r.days, 30);
      expect(r.students.length, 2);
    });

    test('usa days=30 quando ausente', () {
      final r = PunctualityReport.fromJson({'academy_id': 'ac1'});
      expect(r.days, 30);
    });

    test('students vazia quando ausente', () {
      final r = PunctualityReport.fromJson({'academy_id': 'ac1', 'days': 7});
      expect(r.students, isEmpty);
    });
  });

  group('PunctualityReport.avgPct', () {
    test('calcula média corretamente', () {
      final r = PunctualityReport.fromJson({
        'academy_id': 'ac1',
        'days': 30,
        'students': [
          _entryJson(id: 'u1', pct: 80.0),
          _entryJson(id: 'u2', pct: 60.0),
        ],
      });

      expect(r.avgPct, closeTo(70.0, 0.01));
    });

    test('retorna 0 quando lista vazia', () {
      final r = PunctualityReport.fromJson(
          {'academy_id': 'ac1', 'days': 30, 'students': []});
      expect(r.avgPct, 0.0);
    });

    test('retorna o valor exato com um único aluno', () {
      final r = PunctualityReport.fromJson({
        'academy_id': 'ac1',
        'days': 30,
        'students': [_entryJson(pct: 91.5)],
      });
      expect(r.avgPct, closeTo(91.5, 0.01));
    });
  });

  group('PunctualityReport.maxActiveStreak', () {
    test('retorna o maior streak atual entre os alunos', () {
      final r = PunctualityReport.fromJson({
        'academy_id': 'ac1',
        'days': 30,
        'students': [
          _entryJson(id: 'u1', streak: 5),
          _entryJson(id: 'u2', streak: 12),
          _entryJson(id: 'u3', streak: 3),
        ],
      });

      expect(r.maxActiveStreak, 12);
    });

    test('retorna 0 quando todos com streak zero', () {
      final r = PunctualityReport.fromJson({
        'academy_id': 'ac1',
        'days': 30,
        'students': [
          _entryJson(id: 'u1', streak: 0),
          _entryJson(id: 'u2', streak: 0),
        ],
      });

      expect(r.maxActiveStreak, 0);
    });

    test('retorna 0 quando lista vazia', () {
      final r = PunctualityReport.fromJson(
          {'academy_id': 'ac1', 'days': 30, 'students': []});
      expect(r.maxActiveStreak, 0);
    });
  });
}
