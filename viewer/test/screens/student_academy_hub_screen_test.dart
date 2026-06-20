import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/student/student_academy_hub_screen.dart';
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

Map<String, dynamic> _headerStatsJson() => {
      'xp': 250,
      'level': 3,
      'streak': 5,
      'total_points': 400,
      'academy': {
        'id': 'ac1',
        'name': 'Academia Teste',
        'schedule_image_url': null,
        'octophotos_enabled': false,
      },
    };

// Dispatch por URL: /me/header_stats → stats; /partners/featured → lista vazia.
http.Response _dispatch(Uri url) {
  final path = url.path;
  if (path.contains('/me/header_stats')) return _json(_headerStatsJson());
  if (path.contains('/partners/featured')) return _json([]);
  return _json({});
}

Widget _screen() => const MaterialApp(home: StudentAcademyHubScreen());

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

  group('StudentAcademyHubScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(StudentAcademyHubScreen), findsOneWidget);
    });

    testWidgets('não exibe CircularProgressIndicator após carregar',
        (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('StudentAcademyHubScreen — conteúdo', () {
    testWidgets('exibe seção de presença após carregar', (tester) async {
      // Viewport largo para evitar overflow nos Row de tiles 2-colunas.
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      // A tela mostra tiles de presença: QR ou seção PRESENÇA
      expect(
        find.textContaining('QR').evaluate().isNotEmpty ||
            find.textContaining('PRESENÇA').evaluate().isNotEmpty ||
            find.textContaining('Chamada').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('StudentAcademyHubScreen — erro de rede', () {
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

      expect(find.byType(StudentAcademyHubScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
