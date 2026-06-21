import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/engagement_report.dart';

// Testes para EngagementPeriodMetrics e EngagementReport.

Map<String, dynamic> _periodJson({int total = 50, int active = 30}) => {
      'start_date': '2024-06-01',
      'end_date': '2024-06-07',
      'total_students': total,
      'active_students': active,
      'active_rate': (active / total * 100),
    };

void main() {
  group('EngagementPeriodMetrics.fromJson', () {
    test('desserializa todos os campos', () {
      final m = EngagementPeriodMetrics.fromJson(_periodJson());

      expect(m.totalStudents, 50);
      expect(m.activeStudents, 30);
      expect(m.activeRate, closeTo(60.0, 0.01));
      expect(m.startDate.month, 6);
    });

    test('usa defaults quando campos ausentes', () {
      final m = EngagementPeriodMetrics.fromJson({});

      expect(m.totalStudents, 0);
      expect(m.activeStudents, 0);
      expect(m.activeRate, 0.0);
    });
  });

  group('EngagementReport.fromJson', () {
    test('desserializa com weekly e monthly', () {
      final r = EngagementReport.fromJson({
        'academy_id': 'ac1',
        'weekly': _periodJson(total: 50, active: 30),
        'monthly': _periodJson(total: 50, active: 40),
      });

      expect(r.academyId, 'ac1');
      expect(r.weekly.activeStudents, 30);
      expect(r.monthly.activeStudents, 40);
    });

    test('academyId pode ser nulo', () {
      final r = EngagementReport.fromJson({
        'weekly': _periodJson(),
        'monthly': _periodJson(),
      });

      expect(r.academyId, isNull);
    });
  });
}
