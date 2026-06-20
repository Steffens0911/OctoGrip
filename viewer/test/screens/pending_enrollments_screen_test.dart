import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/enrollment/pending_enrollments_screen.dart';
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

// Dispatch por URL: /enrollment-invite → token; /pending-enrollments → lista.
http.Response _dispatch(Uri url, List<Map<String, dynamic>> pending) {
  final path = url.path;
  if (path.contains('enrollment-invite')) {
    return _json({'token': 'test-token-abc'});
  }
  if (path.contains('pending-enrollments')) {
    return _json(pending);
  }
  return _json({});
}

Widget _screen() => const MaterialApp(
      home: PendingEnrollmentsScreen(
        academyId: 'ac1',
        academyName: 'Academia Teste',
      ),
    );

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
    setAuthForTesting(user: stubStudent(role: 'professor'));
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('PendingEnrollmentsScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri, []));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(PendingEnrollmentsScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar com nome da academia', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri, []));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Academia Teste'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator após carregar',
        (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri, []));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('PendingEnrollmentsScreen — conteúdo', () {
    testWidgets('exibe card de convite com QR quando token disponível',
        (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri, []));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      // Verifica que algo sobre o convite/link aparece na tela
      expect(
        find.textContaining('link').evaluate().isNotEmpty ||
            find.textContaining('convite').evaluate().isNotEmpty ||
            find.textContaining('QR').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('exibe nome do aluno pendente quando há solicitações',
        (tester) async {
      final client = MockHttpClient();
      final pending = [
        {
          'id': 'enr1',
          'user_id': 'u1',
          'name': 'Pedro Almeida',
          'email': 'pedro@example.com',
          'belt': 'white',
          'status': 'pending',
          'created_at': '2026-06-01T10:00:00',
        }
      ];
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri, pending));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Pedro'), findsWidgets);
    });
  });

  group('PendingEnrollmentsScreen — erro de rede', () {
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

      expect(find.byType(PendingEnrollmentsScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
