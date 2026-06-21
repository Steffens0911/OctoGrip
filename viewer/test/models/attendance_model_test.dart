import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/attendance.dart';

// Testes para modelos de frequência: AttendanceSessionModel,
// AttendanceRecordModel, AttendanceMyStatsModel e outros.

void main() {
  group('AttendanceSessionModel.fromJson', () {
    test('desserializa todos os campos', () {
      final s = AttendanceSessionModel.fromJson({
        'id': 'sess1',
        'academy_id': 'ac1',
        'created_by_user_id': 'u1',
        'status': 'active',
        'title': 'Treino da manhã',
        'starts_at': '2024-06-01T08:00:00Z',
        'ends_at': '2024-06-01T10:00:00Z',
        'expires_at': '2024-06-01T10:30:00Z',
        'present_count': 12,
        'training_session_id': 'ts1',
      });

      expect(s.id, 'sess1');
      expect(s.status, 'active');
      expect(s.presentCount, 12);
      expect(s.endsAt, isNotNull);
      expect(s.trainingSessionId, 'ts1');
    });

    test('campos opcionais podem ser nulos', () {
      final s = AttendanceSessionModel.fromJson({
        'id': 'sess2',
        'created_by_user_id': 'u1',
        'starts_at': '2024-06-01T08:00:00Z',
      });

      expect(s.academyId, isNull);
      expect(s.title, isNull);
      expect(s.endsAt, isNull);
      expect(s.presentCount, 0);
    });
  });

  group('AttendanceRecordModel.fromJson', () {
    test('desserializa todos os campos', () {
      final r = AttendanceRecordModel.fromJson({
        'id': 'rec1',
        'session_id': 'sess1',
        'user_id': 'u1',
        'checked_in_at': '2024-06-01T08:05:00Z',
        'method': 'face',
        'face_recognition': true,
        'added_manually': false,
      });

      expect(r.id, 'rec1');
      expect(r.method, 'face');
      expect(r.faceRecognition, isTrue);
      expect(r.addedManually, isFalse);
    });

    test('usa defaults quando ausentes', () {
      final r = AttendanceRecordModel.fromJson({
        'id': 'rec2',
        'session_id': 'sess1',
        'user_id': 'u2',
        'checked_in_at': '2024-06-01T08:10:00Z',
      });

      expect(r.method, 'qr');
      expect(r.faceRecognition, isFalse);
      expect(r.addedManually, isFalse);
    });
  });

  group('AttendanceMyStatsModel.fromJson', () {
    test('desserializa com campos obrigatórios', () {
      final m = AttendanceMyStatsModel.fromJson({
        'from_date': '2024-06-01',
        'to_date': '2024-06-30',
        'bucket': 'month',
        'total_sessions': 20,
        'total_checkins': 16,
        'percentage': 80.0,
        'lifetime_total_sessions': 100,
        'lifetime_total_checkins': 80,
        'lifetime_percentage': 80.0,
        'history_total': 16,
        'history_limit': 20,
        'history_offset': 0,
      });

      expect(m.totalSessions, 20);
      expect(m.totalCheckins, 16);
      expect(m.percentage, closeTo(80.0, 0.01));
      expect(m.bucket, 'month');
      expect(m.checkinsByPeriod, isEmpty);
      expect(m.history, isEmpty);
    });

    test('usa defaults quando campos numéricos ausentes', () {
      final m = AttendanceMyStatsModel.fromJson({
        'from_date': '2024-06-01',
        'to_date': '2024-06-30',
      });

      expect(m.totalSessions, 0);
      expect(m.totalCheckins, 0);
      expect(m.bucket, 'week');
      expect(m.lastSeenAt, isNull);
    });
  });

  group('AttendanceUserSummaryModel.fromJson', () {
    test('desserializa todos os campos', () {
      final u = AttendanceUserSummaryModel.fromJson({
        'user_id': 'u1',
        'from_dt': '2024-06-01T00:00:00Z',
        'to_dt': '2024-06-30T23:59:59Z',
        'present_count': 14,
        'last_seen_at': '2024-06-29T09:00:00Z',
      });

      expect(u.userId, 'u1');
      expect(u.presentCount, 14);
      expect(u.lastSeenAt, isNotNull);
    });

    test('last_seen_at pode ser nulo', () {
      final u = AttendanceUserSummaryModel.fromJson({
        'user_id': 'u2',
        'from_dt': '2024-06-01T00:00:00Z',
        'to_dt': '2024-06-30T23:59:59Z',
      });

      expect(u.presentCount, 0);
      expect(u.lastSeenAt, isNull);
    });
  });

  group('AttendanceSessionStatModel.fromJson', () {
    test('desserializa todos os campos', () {
      final s = AttendanceSessionStatModel.fromJson({
        'id': 'sess3',
        'title': 'Treino noturno',
        'starts_at': '2024-06-15T19:00:00Z',
        'ends_at': '2024-06-15T21:00:00Z',
        'status': 'closed',
        'present_count': 8,
      });

      expect(s.id, 'sess3');
      expect(s.title, 'Treino noturno');
      expect(s.endsAt, isNotNull);
      expect(s.status, 'closed');
      expect(s.presentCount, 8);
    });

    test('campos opcionais podem ser nulos', () {
      final s = AttendanceSessionStatModel.fromJson({
        'id': 'sess4',
        'starts_at': '2024-06-15T19:00:00Z',
      });

      expect(s.title, isNull);
      expect(s.endsAt, isNull);
      expect(s.status, 'active');
      expect(s.presentCount, 0);
    });
  });

  group('AttendanceStudentStatModel.fromJson', () {
    test('desserializa todos os campos', () {
      final s = AttendanceStudentStatModel.fromJson({
        'user_id': 'u3',
        'email': 'aluno@academia.com',
        'name': 'João Silva',
        'graduation': 'Branca',
        'present_count': 10,
        'total_sessions': 20,
        'attendance_rate': 50.0,
        'last_seen_at': '2024-06-20T09:00:00Z',
      });

      expect(s.userId, 'u3');
      expect(s.email, 'aluno@academia.com');
      expect(s.name, 'João Silva');
      expect(s.attendanceRate, closeTo(50.0, 0.01));
      expect(s.lastSeenAt, isNotNull);
    });

    test('campos opcionais podem ser nulos', () {
      final s = AttendanceStudentStatModel.fromJson({
        'user_id': 'u4',
        'email': 'sem@nome.com',
      });

      expect(s.name, isNull);
      expect(s.graduation, isNull);
      expect(s.lastSeenAt, isNull);
      expect(s.attendanceRate, closeTo(0.0, 0.001));
    });
  });

  group('AttendanceRecordWithSessionModel.fromJson', () {
    test('desserializa todos os campos', () {
      final r = AttendanceRecordWithSessionModel.fromJson({
        'id': 'rec3',
        'session_id': 'sess1',
        'session_title': 'Manhã',
        'session_starts_at': '2024-06-01T08:00:00Z',
        'checked_in_at': '2024-06-01T08:05:00Z',
        'method': 'face',
      });

      expect(r.id, 'rec3');
      expect(r.sessionTitle, 'Manhã');
      expect(r.method, 'face');
    });

    test('method default é qr', () {
      final r = AttendanceRecordWithSessionModel.fromJson({
        'id': 'rec4',
        'session_id': 'sess1',
        'session_starts_at': '2024-06-01T08:00:00Z',
        'checked_in_at': '2024-06-01T08:10:00Z',
      });

      expect(r.sessionTitle, isNull);
      expect(r.method, 'qr');
    });
  });

  group('AttendanceStudentDetailModel.fromJson', () {
    test('desserializa com lista de registros', () {
      final d = AttendanceStudentDetailModel.fromJson({
        'user_id': 'u5',
        'email': 'detalhe@academia.com',
        'present_count': 3,
        'total_sessions': 5,
        'attendance_rate': 60.0,
        'records': [
          {
            'id': 'rec5',
            'session_id': 'sess1',
            'session_starts_at': '2024-06-01T08:00:00Z',
            'checked_in_at': '2024-06-01T08:05:00Z',
          },
        ],
      });

      expect(d.userId, 'u5');
      expect(d.presentCount, 3);
      expect(d.records, hasLength(1));
    });

    test('records vazio quando ausente', () {
      final d = AttendanceStudentDetailModel.fromJson({
        'user_id': 'u6',
        'email': 'sem@registros.com',
      });

      expect(d.records, isEmpty);
      expect(d.attendanceRate, closeTo(0.0, 0.001));
    });
  });

  group('AttendancePeriodBucketModel.fromJson', () {
    test('desserializa todos os campos', () {
      final b = AttendancePeriodBucketModel.fromJson({
        'period_start': '2024-06-01T00:00:00Z',
        'period_end': '2024-06-07T23:59:59Z',
        'label': 'Semana 1',
        'present_count': 3,
      });

      expect(b.label, 'Semana 1');
      expect(b.presentCount, 3);
      expect(b.periodStart.month, 6);
    });

    test('present_count default é 0', () {
      final b = AttendancePeriodBucketModel.fromJson({
        'period_start': '2024-06-01T00:00:00Z',
        'period_end': '2024-06-07T23:59:59Z',
        'label': 'S1',
      });

      expect(b.presentCount, 0);
    });
  });
}
