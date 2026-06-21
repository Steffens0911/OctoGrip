import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/active_students_report.dart';
import 'package:viewer/models/students_attention_report.dart';
import 'package:viewer/models/technique_execution_summary.dart';

// Testes unitários para modelos de relatório: ActiveStudent,
// StudentAttentionItem e TechniqueExecutionSummary.

void main() {
  group('ActiveStudent.fromJson', () {
    test('desserializa todos os campos', () {
      final s = ActiveStudent.fromJson({
        'id': 'u1',
        'email': 'joao@example.com',
        'name': 'João',
        'graduation': 'blue',
        'academy_id': 'ac1',
        'academy_name': 'Academia Teste',
        'last_login_at': '2024-06-01T10:00:00Z',
      });

      expect(s.id, 'u1');
      expect(s.email, 'joao@example.com');
      expect(s.name, 'João');
      expect(s.graduation, 'blue');
      expect(s.lastLoginAt, isNotNull);
    });

    test('aceita campos opcionais nulos', () {
      final s = ActiveStudent.fromJson({'id': 'u2', 'email': 'u2@x.com'});

      expect(s.name, isNull);
      expect(s.academyId, isNull);
      expect(s.lastLoginAt, isNull);
    });
  });

  group('StudentAttentionItem.fromJson', () {
    test('desserializa todos os campos', () {
      final s = StudentAttentionItem.fromJson({
        'user_id': 'u1',
        'name': 'Pedro',
        'email': 'pedro@x.com',
        'graduation': 'purple',
        'academy_id': 'ac1',
        'academy_name': 'Academia',
        'last_seen_at': '2024-05-01T00:00:00Z',
        'days_absent': 30,
      });

      expect(s.userId, 'u1');
      expect(s.name, 'Pedro');
      expect(s.email, 'pedro@x.com');
      expect(s.daysAbsent, 30);
      expect(s.lastSeenAt, isNotNull);
    });

    test('aceita campos opcionais nulos', () {
      final s = StudentAttentionItem.fromJson({
        'user_id': 'u2',
        'email': 'u2@x.com',
      });

      expect(s.name, isNull);
      expect(s.daysAbsent, isNull);
      expect(s.lastSeenAt, isNull);
    });
  });

  group('TechniqueExecutionSummary.fromJson', () {
    test('desserializa todos os campos', () {
      final s = TechniqueExecutionSummary.fromJson({
        'academy_id': 'ac1',
        'before_training_count': 15,
        'after_training_count': 30,
        'total': 45,
        'before_training_percent': 33.3,
      });

      expect(s.academyId, 'ac1');
      expect(s.beforeTrainingCount, 15);
      expect(s.afterTrainingCount, 30);
      expect(s.total, 45);
      expect(s.beforeTrainingPercent, closeTo(33.3, 0.01));
    });

    test('usa defaults quando campos ausentes', () {
      final s = TechniqueExecutionSummary.fromJson({});

      expect(s.academyId, isNull);
      expect(s.beforeTrainingCount, 0);
      expect(s.afterTrainingCount, 0);
      expect(s.total, 0);
      expect(s.beforeTrainingPercent, 0.0);
    });
  });
}
