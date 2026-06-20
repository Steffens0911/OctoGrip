import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/attendance.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/widgets/attendance_add_student_dialog.dart';

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

Map<String, dynamic> _studentItem({
  String id = 's1',
  String name = 'Luciana Paz',
  String belt = 'white',
}) =>
    {'id': id, 'name': name, 'belt': belt, 'avatar_url': null};

Widget _dialog({
  Set<String> presentUserIds = const {},
}) {
  return MaterialApp(
    home: Scaffold(
      body: AttendanceAddStudentDialog(
        api: ApiService(),
        academyId: 'ac1',
        presentUserIds: presentUserIds,
        onConfirm: (_) async => <AttendanceRecordModel>[],
      ),
    ),
  );
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

  group('AttendanceAddStudentDialog — estrutura', () {
    testWidgets('renderiza sem crash com lista de alunos', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_studentItem()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_dialog());
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceAddStudentDialog), findsOneWidget);
    });

    testWidgets('renderiza sem crash com lista vazia', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_dialog());
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceAddStudentDialog), findsOneWidget);
    });
  });

  group('AttendanceAddStudentDialog — conteúdo', () {
    testWidgets('exibe nome do aluno disponível', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (_) async => _json([_studentItem(name: 'Luciana Paz')]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_dialog());
      await tester.pumpAndSettle();

      expect(find.textContaining('Luciana'), findsWidgets);
    });

    testWidgets('exibe campo de busca', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_studentItem()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_dialog());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });

    testWidgets('oculta alunos já presentes', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([
                _studentItem(id: 's1', name: 'Já Presente'),
                _studentItem(id: 's2', name: 'Rafael Novo'),
              ]));
      ApiService().setHttpClientForTesting(client);

      // s1 já está presente — não deve aparecer
      await tester.pumpWidget(_dialog(presentUserIds: {'s1'}));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rafael'), findsWidgets);
      expect(find.textContaining('Já Presente'), findsNothing);
    });
  });

  group('AttendanceAddStudentDialog — erro de rede', () {
    testWidgets('não trava com erro 500', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                '{"detail": "Erro interno"}',
                500,
                headers: {'content-type': 'application/json'},
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_dialog());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
