import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/professor_impact.dart';

// Testes para os modelos de impacto do professor: TechniqueImpact,
// AtRiskStudent e ProfessorImpact (incluindo weekLabel).

Map<String, dynamic> _impactJson() => {
      'week_start': '2024-06-03',
      'week_end': '2024-06-09',
      'students_reached': 20,
      'total_students': 30,
      'completion_rate': 66.7,
      'completion_rate_delta': 5.0,
      'techniques': [
        {
          'technique_name': 'Triângulo',
          'students_completed': 10,
          'total_students': 30,
          'completion_pct': 33.3,
          'missions_count': 2,
          'executions': [
            {'executor_name': 'João', 'opponent_name': 'Pedro'},
          ],
        }
      ],
      'at_risk_students': [
        {'id': 'u1', 'name': 'Carlos', 'days_inactive': 10, 'risk_level': 'warning'},
      ],
      'total_missions_in_academy': 5,
      'total_completions_all_time': 200,
      'daily_video_views': [
        {'view_date': '2024-06-03', 'views_count': 8},
      ],
    };

void main() {
  group('TechniqueImpact.fromJson', () {
    test('desserializa todos os campos incluindo execuções', () {
      final t = TechniqueImpact.fromJson({
        'technique_name': 'Armlock',
        'students_completed': 5,
        'total_students': 20,
        'completion_pct': 25.0,
        'missions_count': 3,
        'executions': [
          {'executor_name': 'Ana', 'opponent_name': null},
        ],
      });

      expect(t.techniqueName, 'Armlock');
      expect(t.studentsCompleted, 5);
      expect(t.completionPct, closeTo(25.0, 0.01));
      expect(t.executions.length, 1);
      expect(t.executions.first.executorName, 'Ana');
    });

    test('execuções vazia quando lista não fornecida', () {
      final t = TechniqueImpact.fromJson({
        'technique_name': 'X',
        'students_completed': 0,
        'total_students': 0,
        'completion_pct': 0.0,
        'missions_count': 0,
      });

      expect(t.executions, isEmpty);
    });
  });

  group('AtRiskStudent.fromJson', () {
    test('desserializa todos os campos', () {
      final s = AtRiskStudent.fromJson({
        'id': 'u1',
        'name': 'Carlos',
        'days_inactive': 15,
        'risk_level': 'alert',
      });

      expect(s.id, 'u1');
      expect(s.name, 'Carlos');
      expect(s.daysInactive, 15);
      expect(s.riskLevel, 'alert');
    });
  });

  group('ProfessorImpact.fromJson', () {
    test('desserializa todos os campos', () {
      final p = ProfessorImpact.fromJson(_impactJson());

      expect(p.studentsReached, 20);
      expect(p.totalStudents, 30);
      expect(p.completionRate, closeTo(66.7, 0.01));
      expect(p.completionRateDelta, closeTo(5.0, 0.01));
      expect(p.techniques.length, 1);
      expect(p.atRiskStudents.length, 1);
      expect(p.dailyVideoViews.length, 1);
    });

    test('completionRateDelta pode ser nulo', () {
      final json = _impactJson()..['completion_rate_delta'] = null;
      final p = ProfessorImpact.fromJson(json);

      expect(p.completionRateDelta, isNull);
    });

    test('weekLabel formata corretamente', () {
      final p = ProfessorImpact.fromJson(_impactJson());

      expect(p.weekLabel, contains('jun'));
      expect(p.weekLabel, contains('2024'));
    });
  });
}
