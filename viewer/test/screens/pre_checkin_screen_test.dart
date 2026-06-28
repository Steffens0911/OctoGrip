import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/training_stats.dart';
import 'package:viewer/screens/student/pre_checkin_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/widgets/student/student_hankins_section.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _session({
  String id = 's1',
  String classDate = '2026-06-25',
  String startTime = '19:00',
  String? label,
  int preCheckinCount = 0,
}) =>
    {
      'id': id,
      'academy_id': 'academy-1',
      'created_by_user_id': 'prof-1',
      'template_id': null,
      'class_date': classDate,
      'start_time': startTime,
      'tolerance_minutes': 15,
      'label': label,
      'status': 'upcoming',
      'opened_at': null,
      'closed_at': null,
      'created_at': '2026-06-20T10:00:00Z',
      'pre_checkin_count': preCheckinCount,
    };

Map<String, dynamic> _checkinStatus({
  String? preCheckinId,
  String? status,
  List<Map<String, dynamic>> confirmants = const [],
}) =>
    {
      'pre_checkin_id': preCheckinId,
      'status': status,
      'confirmed_at': null,
      'cancelled_at': null,
      'confirmants': confirmants,
      'total_confirmed': confirmants.length,
    };

Map<String, dynamic> _confirmedCheckin() => {
      'id': 'pc1',
      'training_session_id': 's1',
      'user_id': 'u-test',
      'academy_id': 'academy-1',
      'status': 'confirmed',
      'confirmed_at': '2026-06-20T15:00:00Z',
      'cancelled_at': null,
    };

Map<String, dynamic> _statsPayload({
  int positionsTotal = 42,
  int rankingPositionsTotal = 3,
  int rankingPositionsTotalOutOf = 10,
  int loginStreakCurrent = 7,
  int loginStreakBest = 15,
  int rankingLoginStreak = 2,
  int rankingLoginStreakOutOf = 10,
  int punctualityStreak = 4,
  int punctualityStreakBest = 12,
  int rankingPunctuality = 1,
  int rankingPunctualityOutOf = 10,
  int trophiesTotal = 5,
  int videosTotal = 89,
  int rankingVideosTotal = 2,
  int rankingVideosTotalOutOf = 10,
  int totalXp = 4820,
  int rankingXp = 5,
  int rankingXpOutOf = 10,
}) =>
    {
      'workouts_last_30_days': 8,
      'days_since_last_workout': 0,
      'positions_last_30_days': 30,
      'positions_total': positionsTotal,
      'avg_top10_workouts_last_30_days': null,
      'avg_top10_positions_last_30_days': null,
      'ranking_positions_total': rankingPositionsTotal,
      'ranking_positions_total_out_of': rankingPositionsTotalOutOf,
      'videos_last_30_days': 12,
      'avg_top10_videos_last_30_days': null,
      'ranking_videos_last_30_days': 3,
      'videos_total': videosTotal,
      'ranking_videos_total': rankingVideosTotal,
      'ranking_videos_total_out_of': rankingVideosTotalOutOf,
      'trophies_total': trophiesTotal,
      'total_xp': totalXp,
      'ranking_xp': rankingXp,
      'ranking_xp_out_of': rankingXpOutOf,
      'login_streak_current': loginStreakCurrent,
      'login_streak_best': loginStreakBest,
      'ranking_login_streak': rankingLoginStreak,
      'ranking_login_streak_out_of': rankingLoginStreakOutOf,
      'punctuality_streak': punctualityStreak,
      'punctuality_streak_best': punctualityStreakBest,
      'ranking_punctuality': rankingPunctuality,
      'ranking_punctuality_out_of': rankingPunctualityOutOf,
    };

MockHttpClient _buildClient({
  List<Map<String, dynamic>>? sessions,
  Map<String, dynamic>? checkinStatus,
  Map<String, dynamic>? stats,
  int postStatus = 201,
}) {
  final client = MockHttpClient();
  final sessionList = sessions ?? [];
  final status = checkinStatus ?? _checkinStatus();

  when(() => client.get(any(), headers: any(named: 'headers')))
      .thenAnswer((inv) async {
    final uri = inv.positionalArguments[0] as Uri;
    if (uri.path.contains('/pre-checkin')) return _json(status);
    if (uri.path.contains('/training-sessions')) return _json(sessionList);
    if (uri.path.contains('/training_stats')) {
      return stats != null ? _json(stats) : http.Response('{}', 500, headers: {'content-type': 'application/json'});
    }
    return _json([]);
  });

  when(
    () => client.post(
      any(),
      headers: any(named: 'headers'),
      body: any(named: 'body'),
    ),
  ).thenAnswer((_) async => _json(_confirmedCheckin(), postStatus));

  return client;
}

Widget _screen({String? date}) => wrapApp(PreCheckinScreen(academyId: 'academy-1', date: date));

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
    registerFallbackValue('');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting();
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('PreCheckinScreen — estado vazio', () {
    testWidgets('exibe mensagem quando não há sessões', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(sessions: []));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Nenhum treino agendado por enquanto.'), findsOneWidget);
    });
  });

  group('PreCheckinScreen — sessão sem confirmação', () {
    testWidgets('exibe nome e horário da sessão', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session(label: 'Adulto GI', startTime: '19:00')],
        checkinStatus: _checkinStatus(),
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      // displayName = "Adulto GI — 19:00"; horário aparece separado em "Horário: 19:00"
      expect(find.textContaining('Adulto GI —'), findsOneWidget);
      expect(find.textContaining('Horário: 19:00'), findsOneWidget);
    });

    testWidgets('exibe botão "Vou estar lá!" quando não confirmado', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session()],
        checkinStatus: _checkinStatus(),
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Vou estar lá!'), findsOneWidget);
    });

    testWidgets('data formatada como dd/mm/aaaa', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session(classDate: '2026-06-25')],
        checkinStatus: _checkinStatus(),
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('25/06/2026'), findsOneWidget);
    });
  });

  group('PreCheckinScreen — sessão já confirmada', () {
    testWidgets('exibe badge "Confirmado ✓"', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session()],
        checkinStatus: _checkinStatus(
          preCheckinId: 'pc1',
          status: 'confirmed',
          confirmants: [
            {'user_id': 'u-test', 'name': 'Aluno Teste', 'avatar_url': null},
          ],
        ),
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Confirmado ✓'), findsOneWidget);
    });

    testWidgets('exibe botão "Cancelar confirmação"', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session()],
        checkinStatus: _checkinStatus(
          preCheckinId: 'pc1',
          status: 'confirmed',
          confirmants: [
            {'user_id': 'u-test', 'name': 'Aluno Teste', 'avatar_url': null},
          ],
        ),
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Cancelar confirmação'), findsOneWidget);
    });
  });

  group('PreCheckinScreen — confirmantes', () {
    testWidgets('exibe contador e link "ver quem" com 2 confirmados', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session()],
        checkinStatus: _checkinStatus(
          confirmants: [
            {'user_id': 'u2', 'name': 'João', 'avatar_url': null},
            {'user_id': 'u3', 'name': 'Maria', 'avatar_url': null},
          ],
        ),
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.textContaining('confirmados'), findsOneWidget);
      expect(find.textContaining('ver quem'), findsOneWidget);
    });

    testWidgets('exibe "1 confirmado" no singular', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session()],
        checkinStatus: _checkinStatus(
          confirmants: [
            {'user_id': 'u2', 'name': 'João', 'avatar_url': null},
          ],
        ),
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.textContaining('1 confirmado'), findsOneWidget);
    });
  });

  group('PreCheckinScreen — erro de rede', () {
    testWidgets('exibe botão "Tentar novamente" em caso de erro', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('Sem conexão'));
      ApiService().setHttpClientForTesting(client);
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Tentar novamente'), findsOneWidget);
    });
  });

  group('PreCheckinScreen — múltiplas sessões', () {
    testWidgets('agrupa sessões por data', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [
          _session(id: 's1', classDate: '2026-06-25', label: 'Manhã'),
          _session(id: 's2', classDate: '2026-06-26', label: 'Noite'),
        ],
        checkinStatus: _checkinStatus(),
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('25/06/2026'), findsOneWidget);
      expect(find.text('26/06/2026'), findsOneWidget);
    });
  });

  group('PreCheckinScreen — hankins section', () {
    testWidgets('exibe seção "Seus números" quando stats disponível', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session()],
        checkinStatus: _checkinStatus(),
        stats: _statsPayload(),
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Seus números'), findsOneWidget);
    });

    testWidgets('exibe valor de técnicas executadas com ranking', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session()],
        checkinStatus: _checkinStatus(),
        stats: _statsPayload(positionsTotal: 42, rankingPositionsTotal: 3, rankingPositionsTotalOutOf: 10),
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);
      expect(find.text('#3 de 10 na academia'), findsWidgets);
    });

    testWidgets('exibe XP total', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session()],
        checkinStatus: _checkinStatus(),
        stats: _statsPayload(totalXp: 4820),
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('4820'), findsOneWidget);
    });

    testWidgets('exibe troféus conquistados', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session()],
        checkinStatus: _checkinStatus(),
        stats: _statsPayload(trophiesTotal: 5),
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('5'), findsWidgets);
      expect(find.textContaining('troféus conquistados'), findsOneWidget);
    });
  });

  group('StudentHankinsSection — widget isolado', () {
    TrainingStats _makeStats({
      int positionsTotal = 100,
      int rankingPositionsTotal = 1,
      int rankingPositionsTotalOutOf = 10,
      int loginStreakCurrent = 7,
      int loginStreakBest = 21,
      int rankingLoginStreak = 2,
      int rankingLoginStreakOutOf = 10,
      int punctualityStreak = 3,
      int punctualityStreakBest = 10,
      int rankingPunctuality = 3,
      int rankingPunctualityOutOf = 10,
      int trophiesTotal = 8,
      int videosTotal = 60,
      int rankingVideosTotal = 4,
      int rankingVideosTotalOutOf = 10,
      int totalXp = 3000,
      int rankingXp = 6,
      int rankingXpOutOf = 10,
    }) =>
        TrainingStats(
          workoutsLast30Days: 8,
          positionsLast30Days: 30,
          positionsTotal: positionsTotal,
          rankingPositionsTotal: rankingPositionsTotal,
          rankingPositionsTotalOutOf: rankingPositionsTotalOutOf,
          videosLast30Days: 12,
          videosTotal: videosTotal,
          rankingVideosTotal: rankingVideosTotal,
          rankingVideosTotalOutOf: rankingVideosTotalOutOf,
          trophiesTotal: trophiesTotal,
          totalXp: totalXp,
          rankingXp: rankingXp,
          rankingXpOutOf: rankingXpOutOf,
          loginStreakCurrent: loginStreakCurrent,
          loginStreakBest: loginStreakBest,
          rankingLoginStreak: rankingLoginStreak,
          rankingLoginStreakOutOf: rankingLoginStreakOutOf,
          punctualityStreak: punctualityStreak,
          punctualityStreakBest: punctualityStreakBest,
          rankingPunctuality: rankingPunctuality,
          rankingPunctualityOutOf: rankingPunctualityOutOf,
        );

    testWidgets('renderiza todos os 6 grupos de métricas', (tester) async {
      await tester.pumpWidget(
        wrapApp(Scaffold(body: SingleChildScrollView(child: StudentHankinsSection(stats: _makeStats())))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Seus números'), findsOneWidget);
      expect(find.textContaining('técnicas'), findsOneWidget);
      expect(find.textContaining('logando'), findsOneWidget);
      expect(find.textContaining('pontual'), findsOneWidget);
      expect(find.textContaining('troféu'), findsOneWidget);
      expect(find.textContaining('vídeos assistidos'), findsOneWidget);
      expect(find.textContaining('XP acumulado'), findsOneWidget);
    });

    testWidgets('exibe plural correto para login streak > 1', (tester) async {
      await tester.pumpWidget(
        wrapApp(Scaffold(body: SingleChildScrollView(child: StudentHankinsSection(stats: _makeStats(loginStreakCurrent: 5))))),
      );
      await tester.pumpAndSettle();
      expect(find.text('dias seguidos logando'), findsOneWidget);
    });

    testWidgets('exibe singular para login streak = 1', (tester) async {
      await tester.pumpWidget(
        wrapApp(Scaffold(body: SingleChildScrollView(child: StudentHankinsSection(stats: _makeStats(loginStreakCurrent: 1))))),
      );
      await tester.pumpAndSettle();
      expect(find.text('dia seguido logando'), findsOneWidget);
    });

    testWidgets('exibe singular para 1 troféu', (tester) async {
      await tester.pumpWidget(
        wrapApp(Scaffold(body: SingleChildScrollView(child: StudentHankinsSection(stats: _makeStats(trophiesTotal: 1))))),
      );
      await tester.pumpAndSettle();
      expect(find.text('troféu conquistado'), findsOneWidget);
    });
  });

  group('PreCheckinScreen — modo filtrado por data (link do professor)', () {
    testWidgets('exibe título com a data formatada', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(sessions: []));
      await tester.pumpWidget(_screen(date: '2026-06-25'));
      await tester.pumpAndSettle();
      expect(find.text('Treinos de 25/06/2026'), findsOneWidget);
    });

    testWidgets('exibe mensagem específica quando sem sessões no dia', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(sessions: []));
      await tester.pumpWidget(_screen(date: '2026-06-25'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum treino encontrado para este dia.'), findsOneWidget);
    });

    testWidgets('exibe sessões do dia informado', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [
          _session(id: 's1', classDate: '2026-06-25', label: 'Manhã'),
          _session(id: 's2', classDate: '2026-06-25', label: 'Noite'),
        ],
        checkinStatus: _checkinStatus(),
      ));
      await tester.pumpWidget(_screen(date: '2026-06-25'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Manhã'), findsOneWidget);
      expect(find.textContaining('Noite'), findsOneWidget);
    });
  });
}
