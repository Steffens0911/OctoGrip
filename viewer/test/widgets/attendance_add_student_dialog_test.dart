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
  String role = 'aluno',
}) =>
    {
      'id': id,
      'name': name,
      'belt': belt,
      'avatar_url': null,
      'role': role,
    };

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

  group('AttendanceAddStudentDialog — papéis', () {
    testWidgets('título fala de presença, não de aluno', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_studentItem()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_dialog());
      await tester.pumpAndSettle();

      expect(find.text('Adicionar presença'), findsOneWidget);
      expect(find.textContaining('Adicionar aluno'), findsNothing);
    });

    testWidgets('exibe rótulo de papel para professor', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([
                _studentItem(
                    id: 'p1',
                    name: 'Carlos Mestre',
                    belt: 'black',
                    role: 'professor'),
              ]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_dialog());
      await tester.pumpAndSettle();

      expect(find.textContaining('Professor'), findsWidgets);
    });

    testWidgets('aluno continua mostrando a faixa', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async =>
              _json([_studentItem(belt: 'blue', role: 'aluno')]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_dialog());
      await tester.pumpAndSettle();

      expect(find.text('Faixa azul'), findsOneWidget);
    });

    testWidgets('staff sem faixa não mostra "Sem faixa"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([
                _studentItem(
                    id: 'g1',
                    name: 'Ana Gestora',
                    belt: '',
                    role: 'gerente_academia'),
              ]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_dialog());
      await tester.pumpAndSettle();

      expect(find.text('Gerente'), findsOneWidget);
      expect(find.text('Sem faixa'), findsNothing);
    });

    testWidgets('busca filtra por papel', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([
                _studentItem(id: 's1', name: 'Luciana Paz', role: 'aluno'),
                _studentItem(
                    id: 'p1',
                    name: 'Carlos Mestre',
                    belt: 'black',
                    role: 'professor'),
              ]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_dialog());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'profess');
      await tester.pumpAndSettle();

      expect(find.textContaining('Carlos'), findsWidgets);
      expect(find.textContaining('Luciana'), findsNothing);
    });

    testWidgets('lista com todos os perfis renderiza todos', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([
                _studentItem(id: 'u1', name: 'Aluna Um', role: 'aluno'),
                _studentItem(id: 'u2', name: 'Prof Dois', role: 'professor'),
                _studentItem(
                    id: 'u3', name: 'Gerente Tres', role: 'gerente_academia'),
                _studentItem(
                    id: 'u4', name: 'Supervisor Quatro', role: 'supervisor'),
                _studentItem(
                    id: 'u5', name: 'Admin Cinco', role: 'administrador'),
              ]));
      ApiService().setHttpClientForTesting(client);

      // Surface alta: a lista é lazy, com a altura padrão só caberiam 2 linhas.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_dialog());
      await tester.pumpAndSettle();

      for (final nome in [
        'Aluna Um',
        'Prof Dois',
        'Gerente Tres',
        'Supervisor Quatro',
        'Admin Cinco',
      ]) {
        expect(find.textContaining(nome), findsWidgets, reason: nome);
      }
      for (final papel in ['Professor', 'Gerente', 'Supervisor', 'Administrador']) {
        expect(find.textContaining(papel), findsWidgets, reason: papel);
      }
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
