import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/admin/user_list_screen.dart';
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

Map<String, dynamic> _userJson({
  String id = 'u1',
  String name = 'João Souza',
  String role = 'aluno',
  String graduation = 'blue',
  String? academyId = 'ac1',
}) =>
    {
      'id': id,
      'email': '$id@test.com',
      'name': name,
      'role': role,
      'graduation': graduation,
      'academy_id': academyId,
      'points_adjustment': 0,
      'login_streak_days': 0,
      'account_frozen': false,
      'gallery_visible': true,
    };

Map<String, dynamic> _academyJson({
  String id = 'ac1',
  String name = 'Academia Teste',
}) =>
    {
      'id': id,
      'name': name,
      'weekly_multiplier_1': 1,
      'weekly_multiplier_2': 1,
      'weekly_multiplier_3': 1,
    };

Widget _screen() => const MaterialApp(home: UserListScreen());

// UserListScreen tem DropdownButtonFormField — usar pumps manuais.
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
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('UserListScreen — aluno sem academia (sem chamada de API)', () {
    testWidgets('renderiza sem crash', (tester) async {
      setAuthForTesting(); // role='aluno', academyId=null → lista vazia
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(UserListScreen), findsOneWidget);
    });

    testWidgets('não exibe CircularProgressIndicator após carregar',
        (tester) async {
      setAuthForTesting();
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('UserListScreen — admin vê lista de usuários', () {
    testWidgets('exibe nome de aluno retornado pela API', (tester) async {
      setAuthForTesting(user: stubStudent(role: 'administrador'));
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        final p = (inv.positionalArguments[0] as Uri).path;
        if (p.endsWith('/academies')) return _json([_academyJson()]);
        if (p.endsWith('/users'))
          return _json([_userJson(name: 'João Souza')]);
        return _json([]);
      });
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('João'), findsWidgets);
    });

    testWidgets('exibe múltiplos alunos', (tester) async {
      setAuthForTesting(user: stubStudent(role: 'administrador'));
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        final p = (inv.positionalArguments[0] as Uri).path;
        if (p.endsWith('/academies')) return _json([_academyJson()]);
        if (p.endsWith('/users'))
          return _json([
            _userJson(id: 'u1', name: 'João Souza'),
            _userJson(id: 'u2', name: 'Maria Fernandes'),
          ]);
        return _json([]);
      });
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('João'), findsWidgets);
      expect(find.textContaining('Maria'), findsWidgets);
    });

    testWidgets('campo de busca está presente', (tester) async {
      setAuthForTesting(user: stubStudent(role: 'administrador'));
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        final p = (inv.positionalArguments[0] as Uri).path;
        if (p.endsWith('/academies')) return _json([_academyJson()]);
        // Retorna um usuário para que a tela exiba o conteúdo (e não o empty state)
        if (p.endsWith('/users')) return _json([_userJson()]);
        return _json([]);
      });
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });
  });

  group('UserListScreen — erro de rede', () {
    testWidgets('não trava com erro 500', (tester) async {
      setAuthForTesting(user: stubStudent(role: 'administrador'));
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
