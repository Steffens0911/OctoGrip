import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/admin/execution_reports_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';

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

Map<String, dynamic> _metricsJson() => {
      'total_completions': 42,
      'completions_last_7_days': 10,
      'unique_users_completed': 8,
      'before_training_count': 20,
      'after_training_count': 22,
      'before_training_percent': 47.6,
    };

Map<String, dynamic> _academyJson({String id = 'ac1', String name = 'Academia Teste'}) =>
    {'id': id, 'name': name};

http.Response _dispatch(Uri url) {
  final path = url.path;
  if (path.contains('/metrics/usage')) return _json(_metricsJson());
  if (path.contains('/academies')) return _json([_academyJson()]);
  return _json({});
}

// ExecutionReportsScreen usa RoleGuard → precisa de ChangeNotifierProvider<AuthService>.
Widget _screen() => ChangeNotifierProvider<AuthService>.value(
      value: AuthService(),
      child: const MaterialApp(home: ExecutionReportsScreen()),
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
    setAuthForTesting(user: stubStudent(role: 'administrador'));
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('ExecutionReportsScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(ExecutionReportsScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Relatórios de execuções"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('execuções'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator após carregar', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ExecutionReportsScreen — conteúdo', () {
    testWidgets('exibe seção de métricas globais', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      // Deve mostrar "premeditadas" ou "naturais" (do texto descritivo)
      expect(
        find.textContaining('premeditadas').evaluate().isNotEmpty ||
            find.textContaining('naturais').evaluate().isNotEmpty ||
            find.textContaining('global').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('ExecutionReportsScreen — erro de rede', () {
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

      expect(find.byType(ExecutionReportsScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
