import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/mission_today.dart';

void main() {
  group('MissionToday.fromJson', () {
    test('mapeia payload completo', () {
      final json = {
        'mission_id': 'm1',
        'technique_id': 't1',
        'lesson_id': 'l1',
        'mission_title': 'Raspagem da meia-guarda',
        'lesson_title': 'Meia-guarda',
        'description': 'Treine a raspagem',
        'video_url': 'https://youtu.be/abcdefghijk',
        'position_name': 'Meia-guarda',
        'technique_name': 'Raspagem',
        'objective': 'Completar 3x',
        'estimated_duration_seconds': 600,
        'weekly_theme': 'Guarda',
        'is_review': true,
        'already_completed': true,
        'multiplier': 2,
      };

      final m = MissionToday.fromJson(json);

      expect(m.missionId, 'm1');
      expect(m.techniqueId, 't1');
      expect(m.lessonId, 'l1');
      expect(m.missionTitle, 'Raspagem da meia-guarda');
      expect(m.objective, 'Completar 3x');
      expect(m.estimatedDurationSeconds, 600);
      expect(m.weeklyTheme, 'Guarda');
      expect(m.isReview, isTrue);
      expect(m.alreadyCompleted, isTrue);
      expect(m.multiplier, 2);
    });

    test('defaults: strings vazias, flags false e multiplier 1', () {
      final m = MissionToday.fromJson({});

      expect(m.missionId, isNull);
      expect(m.missionTitle, '');
      expect(m.lessonTitle, '');
      expect(m.description, '');
      expect(m.videoUrl, '');
      expect(m.positionName, '');
      expect(m.techniqueName, '');
      expect(m.isReview, isFalse);
      expect(m.alreadyCompleted, isFalse);
      expect(m.multiplier, 1);
    });

    test('toJson omite ids nulos e mantém flags', () {
      final m = MissionToday(
        missionTitle: 'X',
        lessonTitle: 'Y',
        description: 'd',
        videoUrl: 'v',
        positionName: 'p',
        techniqueName: 't',
      );
      final json = m.toJson();
      expect(json.containsKey('mission_id'), isFalse);
      expect(json.containsKey('technique_id'), isFalse);
      expect(json['is_review'], isFalse);
      expect(json['multiplier'], 1);
    });
  });

  group('MissionWeek.fromJson', () {
    test('parseia slots, kits e flag de escolha de turma', () {
      final json = {
        'needs_kit_choice': true,
        'selected_kit_id': 'kit-2',
        'entries': [
          {
            'period_label': 'Seg–Ter',
            'mission': {'mission_title': 'Missão A'},
          },
          {'period_label': 'Qua–Qui'}, // sem missão
        ],
        'available_kits': [
          {'kit_id': 'kit-1', 'label': 'Turma Manhã', 'item_count': 3},
          {'kit_id': 'kit-2', 'label': 'Turma Noite', 'item_count': 5},
        ],
      };

      final w = MissionWeek.fromJson(json);

      expect(w.needsKitChoice, isTrue);
      expect(w.selectedKitId, 'kit-2');
      expect(w.entries, hasLength(2));
      expect(w.entries[0].mission?.missionTitle, 'Missão A');
      expect(w.entries[1].mission, isNull);
      expect(w.availableKits, hasLength(2));
      expect(w.availableKits[1].label, 'Turma Noite');
      expect(w.availableKits[1].itemCount, 5);
    });

    test('listas ausentes viram vazias e defaults aplicam', () {
      final w = MissionWeek.fromJson({});
      expect(w.entries, isEmpty);
      expect(w.availableKits, isEmpty);
      expect(w.needsKitChoice, isFalse);
      expect(w.selectedKitId, isNull);
    });
  });
}
