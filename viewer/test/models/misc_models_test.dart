import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/academy_student_list_item.dart';
import 'package:viewer/models/professor.dart';
import 'package:viewer/models/usage_metrics.dart';

// Testes unitários para modelos auxiliares: Professor, AcademyStudentListItem
// e UsageMetrics.

void main() {
  group('Professor.fromJson', () {
    test('desserializa todos os campos', () {
      final p = Professor.fromJson({
        'id': 'p1',
        'name': 'Mestre João',
        'email': 'joao@academia.com',
        'academy_id': 'ac1',
      });

      expect(p.id, 'p1');
      expect(p.name, 'Mestre João');
      expect(p.email, 'joao@academia.com');
      expect(p.academyId, 'ac1');
    });

    test('academyId pode ser nulo', () {
      final p = Professor.fromJson({
        'id': 'p2',
        'name': 'Professor',
        'email': 'prof@x.com',
      });

      expect(p.academyId, isNull);
    });

    test('toJson serializa corretamente', () {
      final p = Professor(id: 'p3', name: 'Ana', email: 'ana@x.com', academyId: 'ac2');
      final j = p.toJson();

      expect(j['id'], 'p3');
      expect(j['name'], 'Ana');
      expect(j['academy_id'], 'ac2');
    });
  });

  group('AcademyStudentListItem.fromJson', () {
    test('desserializa todos os campos', () {
      final s = AcademyStudentListItem.fromJson({
        'id': 'u1',
        'name': 'Pedro',
        'belt': 'blue',
        'avatar_url': 'https://example.com/avatar.png',
      });

      expect(s.id, 'u1');
      expect(s.name, 'Pedro');
      expect(s.belt, 'blue');
      expect(s.avatarUrl, 'https://example.com/avatar.png');
    });

    test('aceita todos os campos opcionais nulos', () {
      final s = AcademyStudentListItem.fromJson({'id': 'u2'});

      expect(s.name, isNull);
      expect(s.belt, isNull);
      expect(s.avatarUrl, isNull);
    });
  });

  group('UsageMetrics.fromJson', () {
    test('desserializa todos os campos', () {
      final m = UsageMetrics.fromJson({
        'total_completions': 500,
        'completions_last_7_days': 45,
        'unique_users_completed': 30,
        'before_training_count': 200,
        'after_training_count': 300,
        'before_training_percent': 40.0,
      });

      expect(m.totalCompletions, 500);
      expect(m.completionsLast7Days, 45);
      expect(m.uniqueUsersCompleted, 30);
      expect(m.beforeTrainingCount, 200);
      expect(m.afterTrainingCount, 300);
      expect(m.beforeTrainingPercent, closeTo(40.0, 0.01));
    });

    test('usa defaults quando campos ausentes', () {
      final m = UsageMetrics.fromJson({});

      expect(m.totalCompletions, 0);
      expect(m.completionsLast7Days, 0);
      expect(m.uniqueUsersCompleted, 0);
      expect(m.beforeTrainingPercent, 0.0);
    });
  });
}
