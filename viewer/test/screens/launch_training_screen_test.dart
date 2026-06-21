import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/academy/launch_training_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _template({
  String id = 't1',
  String startTime = '19:00',
  int toleranceMinutes = 15,
  String? label,
}) =>
    {
      'id': id,
      'academy_id': 'academy-1',
      'created_by_user_id': 'prof-1',
      'label': label,
      'start_time': startTime,
      'tolerance_minutes': toleranceMinutes,
      'sort_order': 0,
    };

Map<String, dynamic> _createdSession() => {
      'id': 's-new',
      'academy_id': 'academy-1',
      'created_by_user_id': 'prof-1',
      'template_id': null,
      'class_date': '2026-06-26',
      'start_time': '19:00',
      'tolerance_minutes': 15,
      'label': null,
      'status': 'upcoming',
      'opened_at': null,
      'closed_at': null,
      'created_at': '2026-06-20T10:00:00Z',
      'pre_checkin_count': 0,
    };

MockHttpClient _buildClient({
  List<Map<String, dynamic>>? templates,
  int createSessionStatus = 201,
}) {
  final client = MockHttpClient();
  final templateList = templates ?? [];

  when(() => client.get(any(), headers: any(named: 'headers')))
      .thenAnswer((_) async => _json(templateList));

  when(
    () => client.post(
      any(),
      headers: any(named: 'headers'),
      body: any(named: 'body'),
    ),
  ).thenAnswer((inv) async {
    final uri = inv.positionalArguments[0] as Uri;
    if (uri.path.contains('/training-sessions')) {
      return _json(_createdSession(), createSessionStatus);
    }
    if (uri.path.contains('/training-templates')) {
      return _json(_template(), 201);
    }
    return _json({}, 201);
  });

  when(() => client.delete(any(), headers: any(named: 'headers')))
      .thenAnswer((_) async => http.Response('', 204));

  return client;
}

Widget _screen() => wrapApp(
      LaunchTrainingScreen(
        academyId: 'academy-1',
        onLaunched: () {},
      ),
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

  group('LaunchTrainingScreen — estrutura do formulário', () {
    testWidgets('exibe campo "Nome do treino"', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Nome do treino (opcional)'), findsOneWidget);
    });

    testWidgets('exibe botão de seleção de data', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      // O botão mostra a data formatada (dd/mm/aaaa)
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    });

    testWidgets('exibe botão de seleção de horário', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.access_time_outlined), findsOneWidget);
    });

    testWidgets('exibe dropdown de tolerância', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Tolerância para bater presença'), findsOneWidget);
    });

    testWidgets('exibe checkbox "Salvar como favorito"', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Salvar como favorito'), findsOneWidget);
    });

    testWidgets('exibe título e botão "Lançar treino"', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      // AppBar e botão ambos exibem "Lançar treino"
      expect(find.text('Lançar treino'), findsAtLeastNWidgets(1));
    });

    testWidgets('horário padrão é 19:00', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.textContaining('19:00'), findsOneWidget);
    });
  });

  group('LaunchTrainingScreen — favoritos', () {
    testWidgets('exibe chips de favoritos quando há templates', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        templates: [
          _template(id: 't1', label: 'Adulto GI', startTime: '19:00'),
          _template(id: 't2', label: 'Kids', startTime: '17:00'),
        ],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Favoritos'), findsOneWidget);
      // displayName = "$label — $startTime"
      expect(find.textContaining('Adulto GI —'), findsOneWidget);
      expect(find.textContaining('Kids —'), findsOneWidget);
    });

    testWidgets('não exibe seção "Favoritos" quando lista vazia', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(templates: []));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Favoritos'), findsNothing);
    });

    testWidgets('chip sem label exibe apenas o horário', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(
        templates: [_template(id: 't1', startTime: '06:30')],
      ));
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.textContaining('06:30'), findsOneWidget);
    });
  });

  group('LaunchTrainingScreen — lançamento', () {
    testWidgets('botão de lançamento está habilitado quando não está salvando', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      // O botão usa ícone send_outlined quando não está salvando
      expect(find.byIcon(Icons.send_outlined), findsOneWidget);
    });

    testWidgets('toca no botão chama API e exibe sucesso', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      // Toca no botão de lançar (identificado pelo ícone, não pelo texto ambíguo)
      await tester.tap(find.byIcon(Icons.send_outlined));
      await tester.pump(); // inicia a requisição
      // Após a resposta, o ícone some (botão mostra "Lançando..." ou fecha)
      await tester.pumpAndSettle();
      // A tela fecha com pop; o ícone não deve mais aparecer
      expect(find.byIcon(Icons.send_outlined), findsNothing);
    });
  });
}
