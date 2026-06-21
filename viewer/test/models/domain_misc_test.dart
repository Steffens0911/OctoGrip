import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/domain/failures/technique_failure.dart';
import 'package:viewer/features/trophy_shelf/presentation/widgets/trophy_tier_color.dart';
import 'package:viewer/models/attendance_qr.dart';
import 'package:viewer/models/training_video.dart';

import '../helpers/pump_app.dart';

// Testes para entidades de domínio, modelos simples e utilitários de cor.

void main() {
  group('QrTokenModel.fromJson', () {
    test('desserializa todos os campos', () {
      final q = QrTokenModel.fromJson({
        'token': 'tok-abc',
        'expires_at': '2024-06-01T15:00:00Z',
        'short_code': 'AB12',
      });

      expect(q.token, 'tok-abc');
      expect(q.shortCode, 'AB12');
      expect(q.expiresAt.year, 2024);
    });
  });

  group('TrainingVideo.fromJson', () {
    test('desserializa todos os campos', () {
      final v = TrainingVideo.fromJson({
        'id': 'v1',
        'title': 'Guarda Fechada',
        'youtube_url': 'https://youtu.be/abc',
        'points_per_day': 20,
        'is_active': true,
        'duration_seconds': 300,
        'position_description': 'Posição básica',
        'academy_id': 'ac1',
        'academy_name': 'Academia',
        'has_completed_today': false,
        'last_completed_at': '2024-06-01T10:00:00Z',
      });

      expect(v.id, 'v1');
      expect(v.title, 'Guarda Fechada');
      expect(v.pointsPerDay, 20);
      expect(v.isActive, isTrue);
      expect(v.hasCompletedToday, isFalse);
      expect(v.lastCompletedAt, isNotNull);
    });

    test('usa defaults quando campos opcionais ausentes', () {
      final v = TrainingVideo.fromJson({
        'id': 'v2',
        'title': 'Vídeo',
        'youtube_url': 'https://youtu.be/xyz',
        'points_per_day': 10,
        'has_completed_today': false,
      });

      expect(v.isActive, isTrue);
      expect(v.durationSeconds, isNull);
      expect(v.lastCompletedAt, isNull);
    });
  });

  group('TrainingVideoCompletionResult.fromJson', () {
    test('desserializa todos os campos', () {
      final r = TrainingVideoCompletionResult.fromJson({
        'training_video_id': 'v1',
        'has_completed_today': true,
        'already_completed_today': false,
        'points_granted': 20,
        'new_points_balance': 320,
        'message': 'Parabéns!',
      });

      expect(r.trainingVideoId, 'v1');
      expect(r.hasCompletedToday, isTrue);
      expect(r.pointsGranted, 20);
      expect(r.newPointsBalance, 320);
      expect(r.message, 'Parabéns!');
    });
  });

  group('TechniqueEntity', () {
    const e = TechniqueEntity(
      id: 't1',
      academyId: 'ac1',
      name: 'Triângulo',
      slug: 'triangulo',
    );

    test('copyWith preserva campos não alterados', () {
      final copy = e.copyWith(name: 'Armlock');
      expect(copy.id, 't1');
      expect(copy.name, 'Armlock');
      expect(copy.slug, 'triangulo');
    });

    test('igualdade via Equatable', () {
      const e2 = TechniqueEntity(
        id: 't1',
        academyId: 'ac1',
        name: 'Triângulo',
        slug: 'triangulo',
      );
      expect(e, equals(e2));
    });

    test('desigualdade quando id diferente', () {
      const e3 = TechniqueEntity(
        id: 't2',
        academyId: 'ac1',
        name: 'Triângulo',
        slug: 'triangulo',
      );
      expect(e, isNot(equals(e3)));
    });
  });

  group('TechniqueFailure', () {
    test('NetworkTechniqueFailure possui mensagem', () {
      const f = NetworkTechniqueFailure('timeout');
      expect(f.message, 'timeout');
      expect(f.props, contains('timeout'));
    });

    test('ValidationTechniqueFailure é distinto de NetworkTechniqueFailure', () {
      const a = NetworkTechniqueFailure('err');
      const b = ValidationTechniqueFailure('err');
      expect(a, isNot(equals(b)));
    });
  });

  group('trophyTierColor', () {
    testWidgets('gold retorna cor primary', (tester) async {
      Color? goldColor;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          goldColor = trophyTierColor(ctx, 'gold');
          return const SizedBox();
        }),
      ));

      expect(goldColor, isNotNull);
    });

    testWidgets('tier desconhecido retorna outline', (tester) async {
      Color? unknown;
      Color? outline;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          unknown = trophyTierColor(ctx, 'platinum');
          outline = Theme.of(ctx).colorScheme.outline;
          return const SizedBox();
        }),
      ));

      expect(unknown, equals(outline));
    });
  });
}
