import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/training_stats.dart';

void main() {
  group('TrainingStats.fromJson', () {
    test('desserializa campos obrigatórios', () {
      final s = TrainingStats.fromJson({
        'workouts_last_30_days': 12,
        'positions_last_30_days': 45,
        'positions_total': 200,
        'videos_last_30_days': 7,
      });

      expect(s.workoutsLast30Days, 12);
      expect(s.positionsLast30Days, 45);
      expect(s.positionsTotal, 200);
      expect(s.videosLast30Days, 7);
    });

    test('desserializa campos opcionais', () {
      final s = TrainingStats.fromJson({
        'workouts_last_30_days': 5,
        'positions_last_30_days': 20,
        'positions_total': 100,
        'videos_last_30_days': 3,
        'days_since_last_workout': 2,
        'avg_top10_workouts_last_30_days': 8.5,
        'avg_top10_positions_last_30_days': 33.0,
        'ranking_positions_total': 3,
        'ranking_positions_total_out_of': 50,
        'avg_top10_videos_last_30_days': 6.0,
        'ranking_videos_last_30_days': 1,
      });

      expect(s.daysSinceLastWorkout, 2);
      expect(s.avgTop10WorkoutsLast30Days, closeTo(8.5, 0.01));
      expect(s.rankingPositionsTotal, 3);
      expect(s.rankingPositionsTotalOutOf, 50);
    });

    test('aceita campos opcionais nulos', () {
      final s = TrainingStats.fromJson({
        'workouts_last_30_days': 0,
        'positions_last_30_days': 0,
        'positions_total': 0,
        'videos_last_30_days': 0,
      });

      expect(s.daysSinceLastWorkout, isNull);
      expect(s.avgTop10WorkoutsLast30Days, isNull);
      expect(s.rankingPositionsTotal, isNull);
    });
  });
}
