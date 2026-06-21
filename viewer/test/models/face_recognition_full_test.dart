import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/face_recognition.dart';

// Testes adicionais para modelos de reconhecimento facial que ainda têm
// cobertura baixa: FaceRecognitionResultModel, FaceRecognitionJobStatusModel
// e FaceRecognitionEmbeddingStatusModel.

void main() {
  group('FaceRecognitionResultModel.fromJson', () {
    test('desserializa todos os campos com aluno', () {
      final r = FaceRecognitionResultModel.fromJson({
        'face_index': 1,
        'face_crop_base64': 'base64data',
        'status': 'matched',
        'confidence': 0.95,
        'student': {
          'id': 'u1',
          'name': 'João',
          'avatar_url': null,
          'belt': 'blue',
        },
      });

      expect(r.faceIndex, 1);
      expect(r.faceCropBase64, 'base64data');
      expect(r.status, 'matched');
      expect(r.confidence, closeTo(0.95, 0.001));
      expect(r.student, isNotNull);
      expect(r.student!.name, 'João');
    });

    test('student é null quando não há aluno', () {
      final r = FaceRecognitionResultModel.fromJson({
        'face_index': 0,
        'face_crop_base64': '',
        'status': 'no_match',
        'confidence': 0.2,
        'student': null,
      });

      expect(r.student, isNull);
    });

    test('usa defaults quando campos ausentes', () {
      final r = FaceRecognitionResultModel.fromJson({});

      expect(r.faceIndex, 0);
      expect(r.faceCropBase64, '');
      expect(r.status, 'unknown');
      expect(r.confidence, 0.0);
    });
  });

  group('FaceRecognitionJobStatusModel.fromJson', () {
    test('desserializa com resultados', () {
      final m = FaceRecognitionJobStatusModel.fromJson({
        'job_id': 'job-abc',
        'status': 'done',
        'session_id': 'sess-1',
        'total_faces_detected': 2,
        'results': [
          {'face_index': 0, 'face_crop_base64': '', 'status': 'matched', 'confidence': 0.9},
          {'face_index': 1, 'face_crop_base64': '', 'status': 'no_match', 'confidence': 0.1},
        ],
        'error_message': null,
        'reference_photo_base64': null,
      });

      expect(m.jobId, 'job-abc');
      expect(m.status, 'done');
      expect(m.totalFacesDetected, 2);
      expect(m.results.length, 2);
      expect(m.errorMessage, isNull);
    });

    test('resultados vazios quando lista ausente', () {
      final m = FaceRecognitionJobStatusModel.fromJson({
        'job_id': 'job-xyz',
        'session_id': 'sess-2',
      });

      expect(m.results, isEmpty);
      expect(m.totalFacesDetected, 0);
    });
  });

  group('FaceRecognitionEmbeddingStatusModel.fromJson', () {
    test('desserializa com alunos', () {
      final m = FaceRecognitionEmbeddingStatusModel.fromJson({
        'academy_id': 'ac1',
        'total_students': 3,
        'with_embedding': 2,
        'without_embedding': 1,
        'students': [
          {'student_id': 'u1', 'email': 'a@x.com', 'has_embedding': true},
          {'student_id': 'u2', 'email': 'b@x.com', 'has_embedding': false},
        ],
      });

      expect(m.academyId, 'ac1');
      expect(m.totalStudents, 3);
      expect(m.withEmbedding, 2);
      expect(m.students.length, 2);
      expect(m.students.first.hasEmbedding, isTrue);
    });

    test('alunos vazio quando lista ausente', () {
      final m = FaceRecognitionEmbeddingStatusModel.fromJson({
        'academy_id': 'ac1',
      });

      expect(m.students, isEmpty);
    });
  });
}
