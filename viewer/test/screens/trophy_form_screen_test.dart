import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';
import 'package:viewer/screens/admin/trophy_form_screen.dart';
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

Map<String, dynamic> _techJson({
  String id = 'tech1',
  String name = 'Triângulo',
  String slug = 'triangulo',
}) =>
    {'id': id, 'name': name, 'slug': slug};

const _existingTrophy = TrophyEntity(
  id: 'tr1',
  academyId: 'ac1',
  techniqueId: 'tech1',
  name: 'Chave de Braço Ouro',
  startDateIso: '2026-01-01',
  endDateIso: '2026-12-31',
  targetCount: 10,
  awardKind: 'medal',
);

Widget _screen({TrophyEntity? trophy}) => MaterialApp(
      home: TrophyFormScreen(
        academyId: 'ac1',
        trophy: trophy,
      ),
    );

// FormBuilderDropdown usa DropdownButton — animations. Usar pumps manuais.
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
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
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

  group('TrophyFormScreen — novo troféu', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_techJson()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(TrophyFormScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Novo troféu"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_techJson()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('Novo troféu'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator após carregar técnicas',
        (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_techJson()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('exibe campo Nome no formulário', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_techJson()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('Nome'), findsWidgets);
    });

    testWidgets('exibe campo Tipo de premiação', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_techJson()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('premiação'), findsWidgets);
    });
  });

  group('TrophyFormScreen — editar troféu', () {
    testWidgets('exibe AppBar "Editar troféu"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_techJson()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen(trophy: _existingTrophy));
      await _settle(tester);

      expect(find.textContaining('Editar troféu'), findsWidgets);
    });

    testWidgets('pré-preenche nome do troféu existente', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_techJson()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen(trophy: _existingTrophy));
      await _settle(tester);

      expect(find.textContaining('Chave de Braço'), findsWidgets);
    });
  });

  group('TrophyFormScreen — técnicas via API', () {
    testWidgets('exibe nome da técnica carregada da API', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async =>
              _json([_techJson(name: 'Mata-Leão')]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('Mata-Leão'), findsWidgets);
    });

    testWidgets('erro ao carregar técnicas não trava a tela', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                '{"detail": "Erro"}',
                500,
                headers: {'content-type': 'application/json'},
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      // Com erro, _techniques fica vazio mas a tela ainda renderiza
      expect(find.byType(TrophyFormScreen), findsOneWidget);
    });
  });
}
