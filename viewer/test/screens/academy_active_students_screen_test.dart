import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/admin/academy_active_students_screen.dart';
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

// GET /reports/active_students → ActiveStudentsReport
http.Response _reportJson({
  int totalStudents = 10,
  int activeStudents = 5,
  double activeRate = 50.0,
  List<Map<String, dynamic>> students = const [],
}) =>
    _json({
      'academy_id': 'ac1',
      'start_date': '2026-06-12',
      'end_date': '2026-06-19',
      'total_students': totalStudents,
      'active_students': activeStudents,
      'active_rate': activeRate,
      'students': students,
    });

// AcademyActiveStudentsScreen usa RoleGuard → precisa de AuthService no contexto.
Widget _screen() => ChangeNotifierProvider<AuthService>.value(
      value: AuthService(),
      child: MaterialApp(
        home: AcademyActiveStudentsScreen(
          academy: Academy(id: 'ac1', name: 'Academia Teste'),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
    await initializeDateFormatting('pt_BR', null);
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

  group('AcademyActiveStudentsScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _reportJson());
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(AcademyActiveStudentsScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Alunos ativos"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _reportJson());
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Alunos ativos'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator após carregar',
        (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _reportJson());
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('AcademyActiveStudentsScreen — conteúdo', () {
    testWidgets('exibe contagem de alunos ativos', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (_) async => _reportJson(activeStudents: 7, totalStudents: 20));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('7'), findsWidgets);
      expect(find.textContaining('20'), findsWidgets);
    });

    testWidgets('exibe mensagem quando não há alunos ativos', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async =>
              _reportJson(activeStudents: 0, students: []));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Nenhum aluno ativo'), findsWidgets);
    });

    testWidgets('exibe nome de aluno ativo na lista', (tester) async {
      // Viewport alto para garantir que a ListView aninhada (shrinkWrap)
      // não fique abaixo do fold.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _reportJson(
                activeStudents: 1,
                students: [
                  {
                    'id': 'u1',
                    'email': 'aluno@test.com',
                    'name': 'Carlos Souza',
                    'graduation': 'blue',
                    'academy_id': 'ac1',
                    'academy_name': null,
                    'last_login_at': null,
                  }
                ],
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Carlos Souza'), findsWidgets);
    });
  });

  group('AcademyActiveStudentsScreen — erro de rede', () {
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

      expect(find.byType(AcademyActiveStudentsScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
