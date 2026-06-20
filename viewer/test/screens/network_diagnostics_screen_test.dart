import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/debug/network_diagnostics_screen.dart';

import '../helpers/pump_app.dart';

// NetworkDiagnosticsScreen: StatelessWidget puro, sem chamadas de API.

Widget _screen() => const MaterialApp(home: NetworkDiagnosticsScreen());

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NetworkDiagnosticsScreen', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(NetworkDiagnosticsScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Diagnóstico de conexão"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Diagnóstico'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('exibe informações da plataforma', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      // A tela mostra "API base", "Plataforma" ou "Modo" no corpo
      expect(
        find.textContaining('API').evaluate().isNotEmpty ||
            find.textContaining('Plataforma').evaluate().isNotEmpty ||
            find.textContaining('Modo').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
