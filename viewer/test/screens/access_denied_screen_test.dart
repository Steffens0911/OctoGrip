import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/screens/access_denied_screen.dart';

import '../helpers/pump_app.dart';

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  group('AccessDeniedScreen', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AccessDeniedScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessDeniedScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Acesso Negado"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AccessDeniedScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Acesso Negado'), findsWidgets);
    });

    testWidgets('exibe mensagem de sem permissão', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AccessDeniedScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('permissão'), findsWidgets);
    });

    testWidgets('exibe botão Voltar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AccessDeniedScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Voltar'), findsWidgets);
    });
  });
}
