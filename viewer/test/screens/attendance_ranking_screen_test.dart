import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/student/attendance_ranking_screen.dart';
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

Map<String, dynamic> _rankingEntry({
  int position = 1,
  String studentId = 'u1',
  String name = 'Carlos Silva',
  String belt = 'blue',
  int totalCheckins = 20,
  int attendancePercentage = 95,
}) =>
    {
      'position': position,
      'student_id': studentId,
      'name': name,
      'avatar_url': null,
      'belt': belt,
      'total_checkins': totalCheckins,
      'attendance_percentage': attendancePercentage,
      'position_change': null,
    };

Map<String, dynamic> _rankingResponse({
  List<Map<String, dynamic>> ranking = const [],
  Map<String, dynamic>? myPosition,
}) =>
    {
      'month': '2026-06',
      'period_kind': 'month',
      'period_label': 'junho 2026',
      'period_start': '2026-06-01T00:00:00',
      'period_end': '2026-06-30T23:59:59',
      'ranking': ranking,
      'my_position': myPosition,
    };

Widget _screen() => const MaterialApp(
      home: AttendanceRankingScreen(academyId: 'ac1'),
    );

// Pump manual para evitar pumpAndSettle timeout com DropdownButtonFormField.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 100));
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
    ApiService().invalidateCache(); // limpa cache in-memory entre testes
    clearAuthForTesting();
  });

  group('AttendanceRankingScreen — estrutura', () {
    testWidgets('mostra título "Ranking de frequência"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json(_rankingResponse()));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.text('Ranking de frequência'), findsOneWidget);
    });

    testWidgets('renderiza sem crash com ranking vazio', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json(_rankingResponse()));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(AttendanceRankingScreen), findsOneWidget);
    });
  });

  group('AttendanceRankingScreen — com dados', () {
    testWidgets('exibe nome do aluno do ranking', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json(_rankingResponse(
                ranking: [_rankingEntry(name: 'Carlos Silva')],
              )));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('Carlos'), findsWidgets);
    });

    testWidgets('exibe múltiplos alunos no ranking', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json(_rankingResponse(ranking: [
                _rankingEntry(position: 1, name: 'Ana Costa'),
                _rankingEntry(
                    position: 2, studentId: 'u2', name: 'Bruno Dias'),
                _rankingEntry(
                    position: 3, studentId: 'u3', name: 'Cláudia Ferro'),
              ])));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('Ana'), findsWidgets);
      expect(find.textContaining('Bruno'), findsWidgets);
    });
  });

  group('AttendanceRankingScreen — estado de erro', () {
    testWidgets('exibe estado de erro quando API falha com 500', (tester) async {
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

  group('AttendanceRankingScreen — sem academia', () {
    testWidgets('renderiza sem crash com academyId vazio', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json(_rankingResponse()));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(const MaterialApp(
        home: AttendanceRankingScreen(academyId: ''),
      ));
      await _settle(tester);

      expect(find.byType(AttendanceRankingScreen), findsOneWidget);
    });
  });
}
