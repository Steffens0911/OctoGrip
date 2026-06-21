import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/face_recognition.dart';

void main() {
  group('FaceRecognitionSubmitResponse.fromJson', () {
    test('desserializa todos os campos', () {
      final r = FaceRecognitionSubmitResponse.fromJson({
        'job_id': 'job-123',
        'status': 'pending',
        'message': 'Em processamento',
      });

      expect(r.jobId, 'job-123');
      expect(r.status, 'pending');
      expect(r.message, 'Em processamento');
    });

    test('usa defaults quando status e message ausentes', () {
      final r = FaceRecognitionSubmitResponse.fromJson({'job_id': 'j1'});

      expect(r.status, 'pending');
      expect(r.message, '');
    });
  });

  group('FaceRecognitionStudentModel.fromJson', () {
    test('desserializa todos os campos', () {
      final s = FaceRecognitionStudentModel.fromJson({
        'id': 'u1',
        'name': 'João',
        'avatar_url': 'https://example.com/avatar.png',
        'belt': 'blue',
      });

      expect(s.id, 'u1');
      expect(s.name, 'João');
      expect(s.avatarUrl, 'https://example.com/avatar.png');
      expect(s.belt, 'blue');
    });

    test('aceita campos opcionais nulos', () {
      final s = FaceRecognitionStudentModel.fromJson({'id': 'u2'});

      expect(s.id, 'u2');
      expect(s.name, isNull);
      expect(s.avatarUrl, isNull);
      expect(s.belt, isNull);
    });
  });
}
