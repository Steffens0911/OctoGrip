import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/academy/attendance_frequency_screen.dart';
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

Map<String, dynamic> _session({
  String id = 's1',
  String title = 'Treino manhã',
  int presentCount = 8,
}) =>
    {
      'id': id,
      'title': title,
      'starts_at': '2026-06-10T08:00:00Z',
      'ends_at': '2026-06-10T09:30:00Z',
      'status': 'closed',
      'present_count': presentCount,
    };

Map<String, dynamic> _student({
  String userId = 'u1',
  String name = 'Marcos Lima',
  int presentCount = 5,
  int totalSessions = 10,
  double attendanceRate = 50.0,
}) =>
    {
      'user_id': userId,
      'email': '$userId@test.com',
      'name': name,
      'graduation': 'blue',
      'present_count': presentCount,
      'total_sessions': totalSessions,
      'attendance_rate': attendanceRate,
      'last_seen_at': null,
    };

http.Response _dispatch(Uri uri) {
  final p = uri.path;
  if (p.endsWith('/attendance/stats/sessions')) return _json([_session()]);
  if (p.endsWith('/attendance/stats/students')) return _json([_student()]);
  return _json([]);
}

Widget _screen() => const MaterialApp(home: AttendanceFrequencyScreen());

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
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('AttendanceFrequencyScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(AttendanceFrequencyScreen), findsOneWidget);
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

  group('AttendanceFrequencyScreen — dados', () {
    testWidgets('exibe nome da sessão de treino', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        final p = (inv.positionalArguments[0] as Uri).path;
        if (p.endsWith('/attendance/stats/sessions'))
          return _json([_session(title: 'Treino manhã')]);
        if (p.endsWith('/attendance/stats/students')) return _json([]);
        return _json([]);
      });
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('Treino'), findsWidgets);
    });

    testWidgets('exibe nome de aluno na aba alunos', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      // Navegar para aba de alunos (índice 1)
      await tester.tap(find.byType(Tab).last);
      await _settle(tester);

      expect(find.textContaining('Marcos'), findsWidgets);
    });
  });

  group('AttendanceFrequencyScreen — erro de rede', () {
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
