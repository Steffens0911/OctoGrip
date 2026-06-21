import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/mission_completion_report.dart';
import 'package:viewer/models/mission_history_item.dart';
import 'package:viewer/models/weekly_panel_login_report.dart';

// Testes unitários para modelos de missão e painel semanal.

void main() {
  group('MissionHistoryItem.fromJson', () {
    test('desserializa todos os campos', () {
      final item = MissionHistoryItem.fromJson({
        'lesson_id': 'ls1',
        'lesson_title': 'Guarda Fechada',
        'completed_at': '2024-06-01T10:00:00Z',
        'usage_type': 'after_training',
      });

      expect(item.lessonId, 'ls1');
      expect(item.lessonTitle, 'Guarda Fechada');
      expect(item.usageType, 'after_training');
      expect(item.completedAt.year, 2024);
    });

    test('lessonId pode ser nulo, title vazio usa default', () {
      final item = MissionHistoryItem.fromJson({
        'completed_at': '2024-01-01T00:00:00Z',
      });

      expect(item.lessonId, isNull);
      expect(item.lessonTitle, '');
      expect(item.usageType, 'after_training');
    });
  });

  group('MissionCompletionReport.fromJson', () {
    test('desserializa todos os campos', () {
      final r = MissionCompletionReport.fromJson({
        'academy_id': 'ac1',
        'from_date': '2024-06-01',
        'to_date': '2024-06-30',
        'total_students': 40,
        'users_completed': 30,
        'completion_rate': 75.0,
      });

      expect(r.academyId, 'ac1');
      expect(r.totalStudents, 40);
      expect(r.usersCompleted, 30);
      expect(r.completionRate, closeTo(75.0, 0.01));
      expect(r.fromDate.month, 6);
    });

    test('usa defaults quando campos ausentes', () {
      final r = MissionCompletionReport.fromJson({});

      expect(r.academyId, isNull);
      expect(r.totalStudents, 0);
      expect(r.completionRate, 0.0);
    });
  });

  group('WeeklyPanelLoginUserItem.fromJson', () {
    test('desserializa todos os campos', () {
      final u = WeeklyPanelLoginUserItem.fromJson({
        'user_id': 'u1',
        'name': 'João',
        'email': 'joao@x.com',
        'role': 'aluno',
        'academy_id': 'ac1',
        'distinct_login_days_in_week': 3,
        'login_days': ['2024-06-03', '2024-06-04', '2024-06-05'],
      });

      expect(u.userId, 'u1');
      expect(u.name, 'João');
      expect(u.role, 'aluno');
      expect(u.distinctLoginDaysInWeek, 3);
      expect(u.loginDays.length, 3);
    });

    test('loginDays vazio quando não fornecido', () {
      final u = WeeklyPanelLoginUserItem.fromJson({
        'user_id': 'u2',
        'email': 'u2@x.com',
        'role': 'professor',
        'distinct_login_days_in_week': 0,
      });

      expect(u.loginDays, isEmpty);
    });
  });
}
