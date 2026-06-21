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
}
