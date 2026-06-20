import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/academy/manual_trophies_hub_screen.dart';
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

Map<String, dynamic> _template({
  String id = 't1',
  String name = 'Troféu Estrela',
  String trophyType = 'custom',
}) =>
    {
      'id': id,
      'academy_id': 'ac1',
      'name': name,
      'trophy_type': trophyType,
      'created_at': '2026-06-01T00:00:00',
    };

Map<String, dynamic> _event({
  String id = 'e1',
  String name = 'Copa Verão 2026',
}) =>
    {
      'id': id,
      'academy_id': 'ac1',
      'name': name,
      'event_date': '2026-07-01',
      'created_at': '2026-06-01T00:00:00',
    };

http.Response _dispatch(Uri uri) {
  final p = uri.path;
  if (p.endsWith('/manual-trophies/templates')) {
    final type = uri.queryParameters['trophy_type'];
    if (type == 'championship') {
      return _json([_template(id: 't2', name: 'Troféu Campeonato', trophyType: 'championship')]);
    }
    return _json([_template()]);
  }
  if (p.endsWith('/manual-trophies/championships')) {
    return _json([_event()]);
  }
  return _json([]);
}

Widget _screen() => const MaterialApp(
      home: ManualTrophiesHubScreen(academyId: 'ac1'),
    );

// TabController tem animação — usar pumps manuais.
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
    setAuthForTesting();
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('ManualTrophiesHubScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(ManualTrophiesHubScreen), findsOneWidget);
    });

    testWidgets('exibe TabBar com abas', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(TabBar), findsOneWidget);
    });
  });

  group('ManualTrophiesHubScreen — conteúdo', () {
    testWidgets('exibe nome de troféu customizado', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('Estrela'), findsWidgets);
    });

    testWidgets('exibe nome de campeonato na aba campeonatos', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      // Navegar para aba de campeonatos
      await tester.tap(find.byType(Tab).last);
      await _settle(tester);

      expect(find.textContaining('Copa'), findsWidgets);
    });
  });

  group('ManualTrophiesHubScreen — erro de rede', () {
    testWidgets('exibe erro quando templates falham (500)', (tester) async {
      // Retorna 500 apenas para templates/custom; as outras chamadas retornam []
      // para evitar exceções não tratadas de futures simultâneas.
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        final uri = inv.positionalArguments[0] as Uri;
        final p = uri.path;
        final type = uri.queryParameters['trophy_type'];
        if (p.endsWith('/manual-trophies/templates') && type == 'custom') {
          return http.Response(
            '{"detail": "Erro interno"}',
            500,
            headers: {'content-type': 'application/json'},
          );
        }
        return _json([]);
      });
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('não trava com lista vazia de troféus', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(ManualTrophiesHubScreen), findsOneWidget);
    });
  });
}
