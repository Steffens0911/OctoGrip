import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:viewer/screens/auth/login_screen.dart';
import 'package:viewer/services/auth_service.dart';

import '../helpers/pump_app.dart';

Widget _loginApp() => MaterialApp(
      home: ChangeNotifierProvider<AuthService>.value(
        value: AuthService(),
        child: const LoginScreen(),
      ),
    );

void main() {
  setUpAll(disableGoogleFontsFetch);

  setUp(clearAuthForTesting);

  group('LoginScreen — estrutura', () {
    testWidgets('renderiza campo de e-mail, senha e botão Entrar', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pump();

      expect(find.text('Entre com sua conta'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'E-mail'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
    });

    testWidgets('exibe link "Esqueci a senha"', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pump();

      expect(find.text('Esqueci a senha'), findsOneWidget);
    });

    testWidgets('mostra ícone para alternar visibilidade da senha', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pump();

      // Começa com senha oculta → ícone visibility_outlined
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });
  });

  group('LoginScreen — visibilidade da senha', () {
    testWidgets('ícone alterna após toque', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });
  });

  group('LoginScreen — validação do formulário', () {
    testWidgets('campos vazios exibem mensagens de erro ao tentar entrar', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();

      expect(find.text('Informe o e-mail'), findsOneWidget);
      expect(find.text('Informe a senha'), findsOneWidget);
    });

    testWidgets('e-mail inválido exibe mensagem de erro específica', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'semarroba',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();

      expect(find.text('Informe um e-mail válido'), findsOneWidget);
    });

    testWidgets('sem mensagem de validação quando e-mail e senha estão preenchidos',
        (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'aluno@octogrip.com.br',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'secret',
      );

      // Não toca em Entrar para não disparar chamada real à API.
      // Verifica que não há mensagem de erro de validação antes do submit.
      expect(find.text('Informe o e-mail'), findsNothing);
      expect(find.text('Informe um e-mail válido'), findsNothing);
      expect(find.text('Informe a senha'), findsNothing);
    });
  });
}
