import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/face_checkin.dart';
import 'package:viewer/models/pre_checkin.dart';
import 'package:viewer/models/training_session.dart';

// Testes unitários para modelos: FaceCheckin, PreCheckin, TrainingSession.
// Inclui PreCheckinStatus e suas propriedades computed (isConfirmed, etc).

void main() {
  group('FaceArriveResponse.fromJson', () {
    test('desserializa todos os campos', () {
      final r = FaceArriveResponse.fromJson({
        'matched': true,
        'confidence': 0.92,
        'student_id': 'u1',
        'student_name': 'João',
        'was_punctual': true,
        'punctuality_streak': 5,
        'xp_awarded': 30,
        'greeting': 'Bem-vindo, João!',
        'duplicate': false,
      });

      expect(r.matched, isTrue);
      expect(r.confidence, closeTo(0.92, 0.001));
      expect(r.studentId, 'u1');
      expect(r.studentName, 'João');
      expect(r.wasPunctual, isTrue);
      expect(r.punctualityStreak, 5);
      expect(r.xpAwarded, 30);
      expect(r.greeting, 'Bem-vindo, João!');
      expect(r.duplicate, isFalse);
    });

    test('usa defaults quando xp_awarded ausente', () {
      final r = FaceArriveResponse.fromJson({
        'matched': false,
        'confidence': 0.3,
        'greeting': 'Não reconhecido',
        'duplicate': false,
      });

      expect(r.xpAwarded, 0);
      expect(r.matched, isFalse);
    });
  });

  group('Confirmant.fromJson', () {
    test('desserializa todos os campos', () {
      final c = Confirmant.fromJson({
        'user_id': 'u1',
        'name': 'Pedro',
        'avatar_url': 'https://example.com/avatar.png',
      });

      expect(c.userId, 'u1');
      expect(c.name, 'Pedro');
      expect(c.avatarUrl, 'https://example.com/avatar.png');
    });

    test('aceita avatarUrl nulo', () {
      final c = Confirmant.fromJson({'user_id': 'u2', 'name': 'Maria'});

      expect(c.avatarUrl, isNull);
    });
  });

  group('TrainingTemplate.fromJson', () {
    test('desserializa todos os campos', () {
      final t = TrainingTemplate.fromJson({
        'id': 'tt1',
        'academy_id': 'ac1',
        'label': 'Turma da manhã',
        'start_time': '08:00',
        'tolerance_minutes': 15,
        'sort_order': 1,
      });

      expect(t.id, 'tt1');
      expect(t.academyId, 'ac1');
      expect(t.label, 'Turma da manhã');
      expect(t.startTime, '08:00');
      expect(t.toleranceMinutes, 15);
      expect(t.sortOrder, 1);
    });

    test('label pode ser nulo', () {
      final t = TrainingTemplate.fromJson({
        'id': 'tt2',
        'academy_id': 'ac1',
        'start_time': '19:00',
        'tolerance_minutes': 10,
        'sort_order': 2,
      });

      expect(t.label, isNull);
    });
  });

  group('PreCheckinStatus.fromJson', () {
    test('desserializa com confirmantes', () {
      final s = PreCheckinStatus.fromJson({
        'pre_checkin_id': 'pc1',
        'status': 'confirmed',
        'confirmed_at': '2024-06-01T09:00:00Z',
        'confirmants': [
          {'user_id': 'u1', 'name': 'João'},
        ],
        'total_confirmed': 1,
      });

      expect(s.preCheckinId, 'pc1');
      expect(s.isConfirmed, isTrue);
      expect(s.isCancelled, isFalse);
      expect(s.hasConfirmed, isTrue);
      expect(s.totalConfirmed, 1);
      expect(s.confirmants.length, 1);
    });

    test('status cancelled retorna isCancelled true', () {
      final s = PreCheckinStatus.fromJson({
        'status': 'cancelled',
        'cancelled_at': '2024-06-01T09:30:00Z',
      });

      expect(s.isCancelled, isTrue);
      expect(s.isConfirmed, isFalse);
    });

    test('sem status retorna hasConfirmed false', () {
      final s = PreCheckinStatus.fromJson({});

      expect(s.hasConfirmed, isFalse);
      expect(s.confirmants, isEmpty);
      expect(s.totalConfirmed, 0);
    });
  });
}
