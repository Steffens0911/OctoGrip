import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/admin/mission_list_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _missionJson({
  String id = 'm1',
  String techniqueId = 'tech1',
  String? techniqueName = 'Triângulo Frontal',
  String startDate = '2026-01-01',
  String endDate = '2026-12-31',
  String level = 'beginner',
  String? theme = 'Finalização',
}) =>
    {
      'id': id,
      'technique_id': techniqueId,
      'technique_name': techniqueName,
      'start_date': startDate,
      'end_date': endDate,
      'level': level,
      'theme': theme,
      'academy_id': null,
      'is_active': true,
      'multiplier': 30,
    };

Widget _screen() => const MaterialApp(home: MissionListScreen());

// MissionListScreen exibe DropdownButtonFormField quando há itens → usar pumps manuais.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 200));
}

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting(user: stubStudent(role: 'administrador'));
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('MissionListScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(MissionListScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Missões"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Missões'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator após carregar',
        (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('MissionListScreen — estado vazio', () {
    testWidgets('exibe mensagem quando não há missões', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Nenhuma missão'), findsWidgets);
    });
  });

  group('MissionListScreen — conteúdo', () {
    testWidgets('exibe tema da missão', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (_) async => _json([_missionJson(theme: 'Finalização')]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('Finalização'), findsWidgets);
    });

    testWidgets('exibe nome da técnica quando não há tema', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async =>
              _json([_missionJson(theme: null, techniqueName: 'Mata-Leão')]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('Mata-Leão'), findsWidgets);
    });

    testWidgets('exibe múltiplas missões', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([
                _missionJson(id: 'm1', theme: 'Finalização'),
                _missionJson(id: 'm2', theme: 'Guarda'),
              ]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('Finalização'), findsWidgets);
      expect(find.textContaining('Guarda'), findsWidgets);
    });
  });

  group('MissionListScreen — erro de rede', () {
    testWidgets('erro 500 não trava a tela', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                '{"detail": "Erro interno"}',
                500,
                headers: {'content-type': 'application/json'},
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(MissionListScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
