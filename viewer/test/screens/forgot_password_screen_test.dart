import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/auth/forgot_password_screen.dart';

import '../helpers/pump_app.dart';

// ForgotPasswordScreen: formulário simples, sem API no carregamento.

Widget _screen() => const MaterialApp(home: ForgotPasswordScreen());

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ForgotPasswordScreen', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });

    testWidgets('exibe título "Recuperar senha"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Recuperar'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator no carregamento', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('exibe campo de e-mail', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('exibe botão de envio', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(ElevatedButton).evaluate().isNotEmpty ||
             find.byType(FilledButton).evaluate().isNotEmpty ||
             find.textContaining('Enviar').evaluate().isNotEmpty, isTrue);
    });
  });
}
