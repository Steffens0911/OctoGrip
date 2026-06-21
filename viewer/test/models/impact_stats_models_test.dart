import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/manual_trophy.dart';
import 'package:viewer/models/professor_impact.dart';
import 'package:viewer/models/user_academy_stats.dart';

// Testes unitários para TrophyTemplate, ChampionshipEvent, TrophyAward,
// UserTrophyAwardsResponse, ProfessorImpact e UserAcademyStats.

void main() {
  group('TrophyTemplate.fromJson', () {
    test('desserializa todos os campos', () {
      final t = TrophyTemplate.fromJson({
        'id': 'tmpl1',
        'academy_id': 'ac1',
        'name': 'Campeão de Ouro',
        'description': 'Para o melhor do mês',
        'icon': 'star',
        'color': '#FFD700',
        'trophy_type': 'championship',
        'created_by': 'u1',
        'created_at': '2024-01-01T00:00:00Z',
      });

      expect(t.id, 'tmpl1');
      expect(t.academyId, 'ac1');
      expect(t.name, 'Campeão de Ouro');
      expect(t.description, 'Para o melhor do mês');
      expect(t.trophyType, 'championship');
    });

    test('aceita campos opcionais nulos', () {
      final t = TrophyTemplate.fromJson({
        'id': 'tmpl2',
        'academy_id': 'ac1',
        'name': 'Troféu Custom',
        'trophy_type': 'custom',
        'created_at': '2024-06-01T00:00:00Z',
      });

      expect(t.description, isNull);
      expect(t.icon, isNull);
      expect(t.color, isNull);
      expect(t.createdBy, isNull);
    });
  });

  group('ExecutionDetail.fromJson', () {
    test('desserializa todos os campos', () {
      final e = ExecutionDetail.fromJson({
        'executor_name': 'João',
        'opponent_name': 'Pedro',
      });

      expect(e.executorName, 'João');
      expect(e.opponentName, 'Pedro');
    });

    test('opponentName pode ser nulo', () {
      final e = ExecutionDetail.fromJson({'executor_name': 'Maria'});

      expect(e.opponentName, isNull);
    });
  });

  group('DailyVideoView.fromJson', () {
    test('desserializa data e contagem', () {
      final v = DailyVideoView.fromJson({
        'view_date': '2024-06-01',
        'views_count': 12,
      });

      expect(v.viewsCount, 12);
      expect(v.date.year, 2024);
      expect(v.date.month, 6);
      expect(v.date.day, 1);
    });
  });

  group('UserAcademyStats.fromJson', () {
    test('desserializa todos os campos', () {
      final s = UserAcademyStats.fromJson({
        'user_id': 'u1',
        'videos_in_period': 10,
        'positions_in_period': 25,
        'workouts_in_period': 8,
        'trophies_count': 3,
        'days_since_last_workout': 2,
      });

      expect(s.userId, 'u1');
      expect(s.videosInPeriod, 10);
      expect(s.positionsInPeriod, 25);
      expect(s.workoutsInPeriod, 8);
      expect(s.trophiesCount, 3);
      expect(s.daysSinceLastWorkout, 2);
    });

    test('daysSinceLastWorkout pode ser nulo', () {
      final s = UserAcademyStats.fromJson({
        'user_id': 'u2',
        'videos_in_period': 0,
        'positions_in_period': 0,
        'workouts_in_period': 0,
        'trophies_count': 0,
      });

      expect(s.daysSinceLastWorkout, isNull);
    });
  });

  group('ChampionshipEvent.fromJson', () {
    test('desserializa todos os campos', () {
      final e = ChampionshipEvent.fromJson({
        'id': 'ev1',
        'academy_id': 'ac1',
        'name': 'Copa Regional',
        'location': 'São Paulo',
        'event_date': '2024-08-15',
        'created_at': '2024-06-01T00:00:00Z',
      });

      expect(e.id, 'ev1');
      expect(e.name, 'Copa Regional');
      expect(e.location, 'São Paulo');
      expect(e.eventDate, '2024-08-15');
    });

    test('location pode ser nulo', () {
      final e = ChampionshipEvent.fromJson({
        'id': 'ev2',
        'academy_id': 'ac1',
        'name': 'Campeonato',
        'event_date': '2024-09-01',
      });

      expect(e.location, isNull);
    });
  });

  group('TrophyAward.fromJson', () {
    test('desserializa todos os campos', () {
      final a = TrophyAward.fromJson({
        'id': 'aw1',
        'template_id': 'tmpl1',
        'template_name': 'Ouro',
        'trophy_type': 'championship',
        'user_id': 'u1',
        'awarded_at': '2024-08-15T10:00:00Z',
        'championship_event_name': 'Copa Regional',
        'medal_type': 'gold',
        'note': 'Campeão absoluto',
      });

      expect(a.id, 'aw1');
      expect(a.templateName, 'Ouro');
      expect(a.trophyType, 'championship');
      expect(a.medalType, 'gold');
      expect(a.note, 'Campeão absoluto');
    });

    test('usa defaults quando campos opcionais ausentes', () {
      final a = TrophyAward.fromJson({
        'id': 'aw2',
        'template_id': 'tmpl1',
        'template_name': 'Custom',
        'user_id': 'u2',
        'awarded_at': '2024-06-01T00:00:00Z',
      });

      expect(a.trophyType, 'custom');
      expect(a.medalType, isNull);
      expect(a.note, isNull);
    });
  });

  group('UserTrophyAwardsResponse.fromJson', () {
    Map<String, dynamic> _award(String id) => {
          'id': id,
          'template_id': 'tmpl1',
          'template_name': 'Ouro',
          'user_id': 'u1',
          'awarded_at': '2024-08-15T10:00:00Z',
        };

    test('desserializa com listas de troféus', () {
      final r = UserTrophyAwardsResponse.fromJson({
        'user_id': 'u1',
        'championship_awards': [_award('aw1')],
        'custom_awards': [_award('aw2'), _award('aw3')],
      });

      expect(r.userId, 'u1');
      expect(r.championshipAwards.length, 1);
      expect(r.customAwards.length, 2);
    });
  });
}
