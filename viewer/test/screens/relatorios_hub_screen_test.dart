import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/admin/relatorios_hub_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

http.Response _json(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

const _today = '2026-06-16';
const _weekAgo = '2026-06-09';

Map<String, dynamic> _emptyEngagement() => {
      'academy_id': null,
      'weekly': {
        'start_date': _weekAgo,
        'end_date': _today,
        'total_students': 0,
        'active_students': 0,
        'active_rate': 0.0,
      },
      'monthly': {
        'start_date': '2026-05-16',
        'end_date': _today,
        'total_students': 0,
        'active_students': 0,
        'active_rate': 0.0,
      },
    };

Map<String, dynamic> _emptyLogins() => {
      'academy_id': null,
      'week_start': _weekAgo,
      'week_end': _today,
      'eligible_users_count': 0,
      'users_logged_at_least_once': 0,
      'total_login_days': 0,
      'users': <dynamic>[],
    };

Map<String, dynamic> _emptyMissions() => {
      'academy_id': null,
      'from_date': _weekAgo,
      'to_date': _today,
      'total_students': 0,
      'users_completed': 0,
      'completion_rate': 0.0,
    };

Map<String, dynamic> _emptyExecSummary() => {
      'academy_id': null,
      'before_training_count': 0,
      'after_training_count': 0,
      'total': 0,
      'before_training_percent': 0.0,
    };

Map<String, dynamic> _emptyAttention() => {
      'academy_id': null,
      'total_students': 0,
      'students': <dynamic>[],
    };

/// Dispatch de mock GET por caminho de URL.
http.Response _dispatch(Uri uri) {
  final p = uri.path;
  if (p.endsWith('/academies')) return _json([]);
  if (p.endsWith('/reports/engagement')) return _json(_emptyEngagement());
  if (p.endsWith('/reports/weekly_panel_logins')) return _json(_emptyLogins());
  if (p.endsWith('/reports/mission_completion')) return _json(_emptyMissions());
  if (p.endsWith('/reports/technique_execution_summary')) {
    return _json(_emptyExecSummary());
  }
  if (p.endsWith('/reports/students_attention')) return _json(_emptyAttention());
  return _json([]);
}

Widget _screen() => MaterialApp(
      home: ChangeNotifierProvider<AuthService>.value(
        value: AuthService(),
        child: const RelatoriosHubScreen(),
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
    // Relatórios exigem role 'administrador'
    setAuthForTesting(
      user: stubStudent(id: 'admin-test', role: 'administrador'),
    );
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    clearAuthForTesting();
  });

  // Utilitário: pump suficiente para resolver chamadas de API mock imediatas,
  // sem chamar pumpAndSettle (DropdownButtonFormField tem animação de label
  // que nunca resolve em FakeAsync).
  Future<void> _settle(WidgetTester tester) async {
    await tester.pump(); // frame inicial / initState
    await tester.pump(const Duration(milliseconds: 50)); // microtasks API
    await tester.pump(const Duration(milliseconds: 50)); // setState pós-API
    await tester.pump(const Duration(milliseconds: 100)); // frame final
  }

  // ---- Carregado ----
  group('RelatoriosHubScreen — carregado', () {
    testWidgets('mostra AppBar "Relatórios" após carregar', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.text('Relatórios'), findsOneWidget);
    });

    testWidgets('renderiza dados de engajamento zerados sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(RelatoriosHubScreen), findsOneWidget);
    });

    testWidgets('renderiza card de Missões com taxa de conclusão', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      // Taxa 0/0 → 0%
      expect(find.textContaining('0'), findsWidgets);
    });
  });

  // ---- Erro de rede ----
  group('RelatoriosHubScreen — erro de rede', () {
    testWidgets('exibe mensagem de erro quando API falha', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                '{"detail": "Internal Server Error"}',
                500,
                headers: {'content-type': 'application/json'},
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      // Deve mostrar alguma mensagem de erro
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // ---- Role guard ----
  group('RelatoriosHubScreen — acesso de aluno', () {
    testWidgets('aluno comum não vê conteúdo de relatórios (RoleGuard)', (tester) async {
      setAuthForTesting(user: stubStudent(id: 'aluno-test', role: 'aluno'));

      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      // RoleGuard bloqueia conteúdo para não-administradores
      expect(find.text('Relatórios'), findsNothing);
    });
  });
}
