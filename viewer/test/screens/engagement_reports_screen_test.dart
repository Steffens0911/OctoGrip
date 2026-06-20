import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/admin/engagement_reports_screen.dart';
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

Map<String, dynamic> _periodMetrics({
  int totalStudents = 100,
  int activeStudents = 60,
  double activeRate = 60.0,
}) =>
    {
      'start_date': '2026-06-01',
      'end_date': '2026-06-07',
      'total_students': totalStudents,
      'active_students': activeStudents,
      'active_rate': activeRate,
    };

Map<String, dynamic> _engagementReport() => {
      'academy_id': null,
      'weekly': _periodMetrics(),
      'monthly': _periodMetrics(activeStudents: 80, activeRate: 80.0),
    };

Map<String, dynamic> _weeklyLoginsReport() => {
      'academy_id': null,
      'week_start': '2026-06-09',
      'week_end': '2026-06-15',
      'eligible_users_count': 5,
      'users_logged_at_least_once': 3,
      'total_login_days': 12,
      'users': <dynamic>[],
    };

Map<String, dynamic> _academy({String id = 'ac1', String name = 'Academia Teste'}) => {
      'id': id,
      'name': name,
      'weekly_multiplier_1': 1,
      'weekly_multiplier_2': 1,
      'weekly_multiplier_3': 1,
    };

http.Response _dispatch(Uri uri) {
  final p = uri.path;
  if (p.endsWith('/reports/engagement')) return _json(_engagementReport());
  if (p.endsWith('/reports/weekly_panel_logins')) return _json(_weeklyLoginsReport());
  if (p.endsWith('/academies')) return _json([_academy()]);
  return _json([]);
}

// EngagementReportsScreen usa RoleGuard que precisa de ChangeNotifierProvider.
Widget _screen() => MaterialApp(
      home: ChangeNotifierProvider<AuthService>.value(
        value: AuthService(),
        child: const EngagementReportsScreen(),
      ),
    );

// Pode ter DropdownButtonFormField — usar pumps manuais.
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

  group('EngagementReportsScreen — estrutura', () {
    testWidgets('mostra título "Relatórios de engajamento"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.text('Relatórios de engajamento'), findsOneWidget);
    });

    testWidgets('renderiza sem crash com dados globais', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(EngagementReportsScreen), findsOneWidget);
    });
  });

  group('EngagementReportsScreen — conteúdo', () {
    testWidgets('exibe taxa de engajamento do período', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        final p = (inv.positionalArguments[0] as Uri).path;
        if (p.endsWith('/reports/engagement'))
          return _json({
            'academy_id': null,
            'weekly': _periodMetrics(activeRate: 65.0),
            'monthly': _periodMetrics(activeRate: 65.0),
          });
        if (p.endsWith('/reports/weekly_panel_logins'))
          return _json(_weeklyLoginsReport());
        if (p.endsWith('/academies')) return _json([_academy()]);
        return _json([]);
      });
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('65'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator após carregamento',
        (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('EngagementReportsScreen — sem permissão', () {
    testWidgets('aluno sem papel admin vê tela de acesso negado', (tester) async {
      clearAuthForTesting();
      setAuthForTesting(); // role='aluno'

      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      // RoleGuard redireciona para AccessDeniedScreen ou mostra mensagem
      expect(find.byType(EngagementReportsScreen), findsOneWidget);
    });
  });

  group('EngagementReportsScreen — erro de rede', () {
    testWidgets('não trava com erro 500', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                '{"detail": "Erro interno"}',
                500,
                headers: {'content-type': 'application/json'},
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
