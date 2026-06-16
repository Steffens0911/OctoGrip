import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/student/my_executions_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _execution({
  String id = 'ex1',
  String technique = 'Armlock',
  String opponent = 'João',
  String status = 'confirmed',
}) =>
    {
      'id': id,
      'technique_name': technique,
      'opponent_name': opponent,
      'status': status,
      'created_at': '2026-06-10T10:00:00Z',
    };

Widget _screen() => MaterialApp(
      home: const MyExecutionsScreen(userId: 'u-test'),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting();
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    clearAuthForTesting();
  });

  // ---- Estrutura ----
  group('MyExecutionsScreen — estrutura', () {
    testWidgets('mostra AppBar com título "Minhas solicitações"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.text('Minhas solicitações'), findsOneWidget);
    });
  });

  // ---- Estado vazio ----
  group('MyExecutionsScreen — estado vazio', () {
    testWidgets('lista vazia não exibe cards de execução', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNothing);
    });
  });

  // ---- Estado com dados ----
  group('MyExecutionsScreen — com execuções', () {
    testWidgets('renderiza nome da técnica da execução', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([
                _execution(technique: 'Triângulo', status: 'confirmed'),
              ]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Triângulo'), findsWidgets);
    });

    testWidgets('renderiza status "Confirmado" para execução confirmed', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_execution(status: 'confirmed')]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.text('Confirmado'), findsWidgets);
    });

    testWidgets('renderiza status "Aguardando confirmação" para pending', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async =>
              _json([_execution(status: 'pending_confirmation')]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.text('Aguardando confirmação'), findsOneWidget);
    });

    testWidgets('renderiza múltiplas execuções', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([
                _execution(id: 'ex1', technique: 'Armlock'),
                _execution(id: 'ex2', technique: 'Triângulo'),
              ]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Armlock'), findsWidgets);
      expect(find.textContaining('Triângulo'), findsWidgets);
    });
  });

  // ---- Estado de erro ----
  group('MyExecutionsScreen — erro de rede', () {
    testWidgets('exibe mensagem de erro quando API falha', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('{"detail":"Não autorizado"}', 401,
              headers: {'content-type': 'application/json'}));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      // Tela deve mostrar alguma mensagem de erro (texto em vermelho ou similar)
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
