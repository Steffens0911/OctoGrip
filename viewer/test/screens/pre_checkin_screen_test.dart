import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/student/pre_checkin_screen.dart';
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

MockHttpClient _buildClient({
  List<Map<String, dynamic>>? sessions,
  Map<String, dynamic>? checkinStatus,
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

Widget _screen() => wrapApp(const PreCheckinScreen(academyId: 'academy-1'));

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
}
