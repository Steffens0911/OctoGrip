import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/user.dart' as models;
import 'package:viewer/screens/admin/user_form_screen.dart';
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

models.UserModel _existingUser() => models.UserModel(
      id: 'u1',
      email: 'u1@test.com',
      name: 'Jorge Melo',
      role: 'aluno',
      academyId: 'ac1',
    );

Widget _screen({models.UserModel? user}) => MaterialApp(
      home: UserFormScreen(user: user),
    );

// UserFormScreen tem DropdownButtonFormField — usar pumps manuais.
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

  group('UserFormScreen — novo usuário', () {
    testWidgets('renderiza formulário vazio sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_academyJson()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(UserFormScreen), findsOneWidget);
    });

    testWidgets('mostra campo de e-mail', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_academyJson()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('E-mail'), findsAtLeastNWidgets(1));
    });

    testWidgets('mostra campo de senha', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_academyJson()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.textContaining('Senha'), findsAtLeastNWidgets(1));
    });
  });

  group('UserFormScreen — editar usuário existente', () {
    testWidgets('preenche nome do usuário existente', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_academyJson()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen(user: _existingUser()));
      await _settle(tester);

      expect(find.textContaining('Jorge'), findsWidgets);
    });

    testWidgets('preenche e-mail do usuário existente', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_academyJson()]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen(user: _existingUser()));
      await _settle(tester);

      expect(find.textContaining('u1@test.com'), findsWidgets);
    });
  });

  group('UserFormScreen — erro de rede', () {
    testWidgets('não trava quando API de academias falha', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                '{"detail": "Não autorizado"}',
                403,
                headers: {'content-type': 'application/json'},
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _settle(tester);

      expect(find.byType(UserFormScreen), findsOneWidget);
    });
  });
}
