import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/admin/academy_points_edit_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// AcademyPointsEditScreen chama GET /users (getUsersAll paginado) e então
// GET /academies/{id}/user_points em sequência no initState.
// Dispatch diferencia pelos paths para responder corretamente a cada chamada.

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

// Dispatch: /users → lista vazia; /user_points → mapa vazio.
http.Response _dispatch(Uri uri) {
  final path = uri.path;
  if (path.contains('/user_points')) {
    return _json({'points_by_user': <String, dynamic>{}});
  }
  if (path.contains('/users')) return _json([]);
  return _json({}, 404);
}

Widget _screen() => const MaterialApp(
      home: AcademyPointsEditScreen(
        academyId: 'ac1',
        academyName: 'Academia Teste',
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
    setAuthForTesting(user: stubStudent(role: 'administrador'));
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('AcademyPointsEditScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(AcademyPointsEditScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Editar pontos dos alunos"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('pontos'), findsWidgets);
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

  group('AcademyPointsEditScreen — estado vazio', () {
    testWidgets('exibe mensagem quando não há alunos', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Nenhum aluno'), findsWidgets);
    });
  });

  group('AcademyPointsEditScreen — erro de rede', () {
    testWidgets('erro 500 exibe botão tentar novamente', (tester) async {
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

      expect(find.byType(AcademyPointsEditScreen), findsOneWidget);
      expect(find.textContaining('Tentar novamente'), findsWidgets);
    });
  });
}
