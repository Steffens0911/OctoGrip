import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/attendance_ranking.dart';

void main() {
  group('AttendanceRankingModel.fromJson', () {
    test('parseia ranking, datas do período e minha posição', () {
      final json = {
        'month': '2026-06',
        'period_kind': 'month',
        'period_label': 'Junho/2026',
        'period_start': '2026-06-01T00:00:00Z',
        'period_end': '2026-06-30T23:59:59Z',
        'ranking': [
          {
            'position': 1,
            'student_id': 's1',
            'name': 'Aluno Um',
            'total_checkins': 20,
            'attendance_percentage': 95,
            'position_change': 2,
          },
          {
            'position': 2,
            'student_id': 's2',
            'name': 'Aluno Dois',
            'total_checkins': 18,
            'attendance_percentage': 80,
          },
        ],
        'my_position': {
          'position': 5,
          'total_checkins': 10,
          'attendance_percentage': 50,
          'position_change': -1,
        },
      };

      final m = AttendanceRankingModel.fromJson(json);

      expect(m.month, '2026-06');
      expect(m.periodKind, 'month');
      expect(m.periodLabel, 'Junho/2026');
      expect(m.periodStart, DateTime.parse('2026-06-01T00:00:00Z'));
      expect(m.ranking, hasLength(2));
      expect(m.ranking.first.name, 'Aluno Um');
      expect(m.ranking.first.positionChange, 2);
      expect(m.ranking[1].positionChange, isNull);
      expect(m.myPosition?.position, 5);
      expect(m.myPosition?.positionChange, -1);
    });

    test('ranking ausente vira lista vazia e my_position nulo', () {
      final m = AttendanceRankingModel.fromJson({
        'period_start': '2026-06-01T00:00:00Z',
        'period_end': '2026-06-30T00:00:00Z',
      });
      expect(m.ranking, isEmpty);
      expect(m.myPosition, isNull);
      expect(m.periodKind, 'month'); // default
    });

    test('aceita números inteiros vindos como num/double', () {
      final entry = AttendanceRankingEntryModel.fromJson({
        'position': 1.0,
        'student_id': 's',
        'total_checkins': 12.0,
        'attendance_percentage': 88.0,
      });
      expect(entry.position, 1);
      expect(entry.totalCheckins, 12);
      expect(entry.attendancePercentage, 88);
    });
  });
}
