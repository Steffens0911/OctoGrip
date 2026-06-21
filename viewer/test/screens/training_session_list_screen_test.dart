import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/academy/training_session_list_screen.dart';
import 'package:viewer/services/api_service.dart';

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
  String status = 'upcoming',
  int preCheckinCount = 0,
  String? label,
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
      'status': status,
      'opened_at': status == 'open' ? '2026-06-25T22:00:00Z' : null,
      'closed_at': status == 'closed' ? '2026-06-25T23:00:00Z' : null,
      'created_at': '2026-06-20T10:00:00Z',
      'pre_checkin_count': preCheckinCount,
    };

Map<String, dynamic> _summaryData() => {
      'training_session_id': 's1',
      'label': null,
      'class_date': '2026-06-25',
      'start_time': '19:00',
      'total_pre_confirmed': 0,
      'total_attended': 0,
      'confirmed_and_attended': [],
      'furos': [],
      'surpresas': [],
    };

MockHttpClient _buildClient({
  List<Map<String, dynamic>>? sessions,
}) {
  final client = MockHttpClient();
  final sessionList = sessions ?? [];

  when(() => client.get(any(), headers: any(named: 'headers')))
      .thenAnswer((inv) async {
    final uri = inv.positionalArguments[0] as Uri;
    if (uri.path.contains('/summary')) return _json(_summaryData());
    if (uri.path.contains('/training-sessions') ||
        uri.path.contains('/training-templates')) {
      return _json(sessionList);
    }
    // AttendanceSessionScreen carregado após navegar
    if (uri.path.contains('/attendance')) return _json({});
    return _json([]);
  });

  when(
    () => client.post(
      any(),
      headers: any(named: 'headers'),
      body: any(named: 'body'),
    ),
  ).thenAnswer((inv) async {
    final uri = inv.positionalArguments[0] as Uri;
    final updatedStatus = uri.path.contains('/close') ? 'closed' : 'open';
    final updated = _session(status: updatedStatus);
    return _json(updated, 200);
  });

  when(
    () => client.post(any(), headers: any(named: 'headers')),
  ).thenAnswer((inv) async {
    final uri = inv.positionalArguments[0] as Uri;
    final updatedStatus = uri.path.contains('/close') ? 'closed' : 'open';
    return _json(_session(status: updatedStatus), 200);
  });

  when(() => client.delete(any(), headers: any(named: 'headers')))
      .thenAnswer((_) async => http.Response('', 204));

  return client;
}

Widget _screen() => wrapApp(
      const TrainingSessionListScreen(academyId: 'academy-1'),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
    registerFallbackValue('');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting(user: stubStudent(role: 'professor'));
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    clearAuthForTesting();
  });

  group('TrainingSessionListScreen — estado vazio', () {
    testWidgets('exibe mensagem "Nenhum treino lançado ainda."', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(sessions: []));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Nenhum treino lançado ainda.'), findsOneWidget);
    });

    testWidgets('exibe FAB "Lançar treino"', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(sessions: []));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Lançar treino'), findsOneWidget);
    });
  });

  group('TrainingSessionListScreen — sessão upcoming', () {
    testWidgets('exibe status chip "agendado"', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session(status: 'upcoming')],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('agendado'), findsOneWidget);
    });

    testWidgets('exibe botão "Abrir chamada"', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session(status: 'upcoming')],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Abrir chamada'), findsOneWidget);
    });

    testWidgets('não exibe "Ver resumo" para sessão upcoming', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session(status: 'upcoming')],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Ver resumo'), findsNothing);
    });
  });

  group('TrainingSessionListScreen — sessão open', () {
    testWidgets('exibe chip "aberto" e botão "Encerrar"', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session(status: 'open')],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('aberto'), findsOneWidget);
      expect(find.text('Encerrar'), findsOneWidget);
    });

    testWidgets('não exibe "Abrir chamada" quando open', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session(status: 'open')],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Abrir chamada'), findsNothing);
    });
  });

  group('TrainingSessionListScreen — sessão closed', () {
    testWidgets('exibe chip "encerrado"', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session(status: 'closed', preCheckinCount: 0)],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('encerrado'), findsOneWidget);
    });

    testWidgets('exibe "Ver resumo" quando há pré-checkins', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session(status: 'closed', preCheckinCount: 3)],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Ver resumo'), findsOneWidget);
    });

    testWidgets('não exibe "Ver resumo" quando sem pré-checkins', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session(status: 'closed', preCheckinCount: 0)],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Ver resumo'), findsNothing);
    });

    testWidgets('exibe contagem de confirmados quando > 0', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session(status: 'upcoming', preCheckinCount: 5)],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.textContaining('5 confirmado'), findsOneWidget);
    });
  });

  group('TrainingSessionListScreen — label e data', () {
    testWidgets('exibe label quando preenchido', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session(label: 'Adulto GI', startTime: '19:00')],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.textContaining('Adulto GI'), findsOneWidget);
    });

    testWidgets('exibe data agrupada formatada', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session(classDate: '2026-06-25')],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('25/06/2026'), findsOneWidget);
    });

    testWidgets('exibe tolerância', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        sessions: [_session()],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.textContaining('Tolerância: 15 min'), findsOneWidget);
    });
  });
}
