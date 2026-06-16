import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/auth/reset_password_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

Widget _screen({String token = 'tok-abc'}) =>
    MaterialApp(home: ResetPasswordScreen(token: token));

http.Response _ok() => http.Response(
      jsonEncode({'detail': 'ok'}),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService().setForTesting(token: null, user: null);
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    AuthService().setForTesting(token: null, user: null);
  });

  // ---- Estrutura ----
  group('ResetPasswordScreen — estrutura', () {
    testWidgets('renderiza dois campos de senha e botão Redefinir', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      expect(find.widgetWithText(TextFormField, 'Nova senha'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Confirmar nova senha'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Redefinir senha'), findsOneWidget);
    });

    testWidgets('título "Nova senha" está presente', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      expect(find.text('Nova senha'), findsWidgets);
    });

    testWidgets('ambos os campos começam com senha oculta', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
    });
  });

  // ---- Toggle de visibilidade ----
  group('ResetPasswordScreen — visibilidade', () {
    testWidgets('primeiro ícone alterna após toque', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      final icons = find.byIcon(Icons.visibility_outlined);
      await tester.tap(icons.first);
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('segundo ícone (confirmar) alterna independentemente', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      final icons = find.byIcon(Icons.visibility_outlined);
      await tester.tap(icons.last);
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });
  });

  // ---- Validação ----
  group('ResetPasswordScreen — validação', () {
    testWidgets('campos vazios exibem erros ao submeter', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Redefinir senha'));
      await tester.pump();

      expect(find.text('Informe a nova senha'), findsOneWidget);
    });

    testWidgets('senha com menos de 8 chars exibe erro', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nova senha'),
        '1234567',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Redefinir senha'));
      await tester.pump();

      expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
    });

    testWidgets('senhas diferentes exibem erro de confirmação', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nova senha'),
        'senha123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar nova senha'),
        'outrasenha',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Redefinir senha'));
      await tester.pump();

      expect(find.text('As senhas não coincidem'), findsOneWidget);
    });

    testWidgets('sem erros de validação antes de submeter', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      expect(find.text('Informe a nova senha'), findsNothing);
      expect(find.text('Mínimo 8 caracteres'), findsNothing);
      expect(find.text('As senhas não coincidem'), findsNothing);
    });

    testWidgets('senhas iguais e válidas não exibem erro de confirmação', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nova senha'),
        'senha123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar nova senha'),
        'senha123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Redefinir senha'));
      await tester.pump();

      expect(find.text('As senhas não coincidem'), findsNothing);
    });
  });

  // ---- Estado de sucesso ----
  group('ResetPasswordScreen — estado de sucesso', () {
    testWidgets('exibe confirmação após redefinição bem-sucedida', (tester) async {
      final client = MockHttpClient();
      when(() => client.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _ok());
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nova senha'),
        'novaSenha123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar nova senha'),
        'novaSenha123',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Redefinir senha'));
      await tester.pumpAndSettle();

      expect(find.text('Senha redefinida com sucesso!'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Ir para o login'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Redefinir senha'), findsNothing);
    });
  });
}
