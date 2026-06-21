import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/academy.dart';

// Testes para Academy, AcademyRankingEntry, AcademyDifficultyEntry e
// AcademyWeeklyReport.

Map<String, dynamic> _academyJson() => {
      'id': 'ac1',
      'name': 'Academia Teste',
      'slug': 'academia-teste',
      'logo_url': 'https://example.com/logo.png',
      'show_trophies': true,
      'show_partners': false,
      'login_notice_active': false,
      'face_recognition_enabled': false,
      'qr_attendance_enabled': true,
      'octophotos_enabled': false,
      'user_photos_quota': 30,
      'pre_checkin_enabled': true,
      'pre_checkin_strict': false,
      'face_checkin_enabled': false,
      'punctuality_xp': 20,
    };

void main() {
  group('Academy.fromJson', () {
    test('desserializa campos obrigatórios', () {
      final a = Academy.fromJson(_academyJson());

      expect(a.id, 'ac1');
      expect(a.name, 'Academia Teste');
      expect(a.slug, 'academia-teste');
      expect(a.showTrophies, isTrue);
      expect(a.showPartners, isFalse);
      expect(a.qrAttendanceEnabled, isTrue);
      expect(a.punctualityXp, 20);
    });

    test('usa defaults quando campos booleanos ausentes', () {
      final a = Academy.fromJson({'id': 'ac2', 'name': 'Mini Academia'});

      expect(a.showTrophies, isTrue);
      expect(a.showPartners, isTrue);
      expect(a.loginNoticeActive, isFalse);
      expect(a.faceRecognitionEnabled, isFalse);
      expect(a.preCheckinEnabled, isFalse);
      expect(a.punctualityXp, 15);
    });

    test('toJson inclui campos necessários', () {
      final a = Academy.fromJson(_academyJson());
      final j = a.toJson();

      expect(j['id'], 'ac1');
      expect(j['name'], 'Academia Teste');
      expect(j['qr_attendance_enabled'], isTrue);
      expect(j['punctuality_xp'], 20);
    });
  });

  group('AcademyRankingEntry.fromJson', () {
    test('desserializa todos os campos', () {
      final e = AcademyRankingEntry.fromJson({
        'rank': 1,
        'user_id': 'u1',
        'name': 'João',
        'completions_count': 50,
      });

      expect(e.rank, 1);
      expect(e.userId, 'u1');
      expect(e.name, 'João');
      expect(e.completionsCount, 50);
    });

    test('name pode ser nulo', () {
      final e = AcademyRankingEntry.fromJson({
        'rank': 2,
        'user_id': 'u2',
        'completions_count': 30,
      });

      expect(e.name, isNull);
    });
  });

  group('AcademyDifficultyEntry.fromJson', () {
    test('desserializa todos os campos', () {
      final d = AcademyDifficultyEntry.fromJson({
        'position_id': 'pos1',
        'position_name': 'Guarda Fechada',
        'count': 12,
      });

      expect(d.positionId, 'pos1');
      expect(d.positionName, 'Guarda Fechada');
      expect(d.count, 12);
    });
  });

  group('AcademyWeeklyReport.fromJson', () {
    test('desserializa com entries', () {
      final r = AcademyWeeklyReport.fromJson({
        'academy_id': 'ac1',
        'week_start': '2024-06-03',
        'week_end': '2024-06-09',
        'completions_count': 100,
        'active_users_count': 25,
        'entries': [
          {'rank': 1, 'user_id': 'u1', 'completions_count': 15},
        ],
      });

      expect(r.academyId, 'ac1');
      expect(r.completionsCount, 100);
      expect(r.activeUsersCount, 25);
      expect(r.entries.length, 1);
      expect(r.entries.first.rank, 1);
    });

    test('entries vazio quando lista ausente', () {
      final r = AcademyWeeklyReport.fromJson({
        'academy_id': 'ac1',
        'week_start': '2024-06-03',
        'week_end': '2024-06-09',
        'completions_count': 0,
        'active_users_count': 0,
      });

      expect(r.entries, isEmpty);
    });
  });
}
