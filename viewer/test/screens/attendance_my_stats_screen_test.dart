import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/student/attendance_my_stats_screen.dart';
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

Map<String, dynamic> _statsResponse({
  int totalSessions = 10,
  int totalCheckins = 8,
  double percentage = 80.0,
}) =>
    {
      'from_date': '2026-06-01',
      'to_date': '2026-06-30',
      'bucket': 'week',
      'total_sessions': totalSessions,
      'total_checkins': totalCheckins,
      'percentage': percentage,
      'last_seen_at': null,
      'lifetime_total_sessions': 100,
      'lifetime_total_checkins': 80,
      'lifetime_percentage': 80.0,
      'checkins_by_period': <dynamic>[],
      'history': <dynamic>[],
      'history_total': 0,
      'history_limit': 30,
      'history_offset': 0,
    };

Widget _screen() => const MaterialApp(
      home: AttendanceMyStatsScreen(),
    );

// Pump manual — TabController tem animação que bloqueia pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
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
    setAuthForTesting();
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    clearAuthForTesting();
  });

  group('AttendanceMyStatsScreen — estrutura', () {
    testWidgets('renderiza sem crash com dados zerados', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async =>
              _json(_statsResponse(totalSessions: 0, totalCheckins: 0, percentage: 0)));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(AttendanceMyStatsScreen), findsOneWidget);
    });

    testWidgets('renderiza sem crash com dados reais', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json(_statsResponse()));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(AttendanceMyStatsScreen), findsOneWidget);
    });
  });

  group('AttendanceMyStatsScreen — conteúdo', () {
    testWidgets('exibe percentual de frequência', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json(_statsResponse(percentage: 80.0)));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      // 80% de frequência deve aparecer em algum lugar
      expect(find.textContaining('80'), findsWidgets);
    });

    testWidgets('exibe TabBar com múltiplas abas', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json(_statsResponse()));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(TabBar), findsOneWidget);
    });
  });

  group('AttendanceMyStatsScreen — erro de rede', () {
    testWidgets('exibe estado de erro quando API falha', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                '{"detail": "Não autorizado"}',
                401,
                headers: {'content-type': 'application/json'},
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
