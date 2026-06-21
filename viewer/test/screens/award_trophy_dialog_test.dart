import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/manual_trophy.dart';
import 'package:viewer/screens/academy/award_trophy_dialog.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// AwardTrophyDialog: initState chama getAcademyStudentsForSelection → GET /users?academy_id=ac1.
// Exibido diretamente como home (sem showDialog) para simplicidade de teste.

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

TrophyTemplate _template({String trophyType = 'trophy'}) => TrophyTemplate(
      id: 'tmpl1',
      academyId: 'ac1',
      name: 'Troféu Teste',
      trophyType: trophyType,
      createdAt: '2024-01-01T00:00:00Z',
    );

Widget _screen({TrophyTemplate? template}) => MaterialApp(
      home: Scaffold(
        body: AwardTrophyDialog(
          academyId: 'ac1',
          template: template ?? _template(),
        ),
      ),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting(user: stubStudent(role: 'professor'));
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('AwardTrophyDialog — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(AwardTrophyDialog), findsOneWidget);
    });

    testWidgets('não exibe CircularProgressIndicator após carregar alunos', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('AwardTrophyDialog — busca de aluno', () {
    testWidgets('exibe campo de busca', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Buscar'), findsWidgets);
    });

    testWidgets('lista vazia não trava a tela', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(AwardTrophyDialog), findsOneWidget);
    });

    testWidgets('exibe nome do aluno na lista quando há alunos', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([
                {
                  'id': 'u1',
                  'name': 'João Silva',
                  'email': 'joao@test.com',
                  'role': 'aluno',
                  'academy_id': 'ac1',
                  'points_adjustment': 0,
                  'belt': 'white',
                  'stripes': 0,
                }
              ]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('João Silva'), findsWidgets);
    });
  });

  group('AwardTrophyDialog — erro de rede', () {
    testWidgets('erro 500 não trava a tela', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                '{"detail": "Erro"}',
                500,
                headers: {'content-type': 'application/json'},
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(AwardTrophyDialog), findsOneWidget);
    });
  });
}
