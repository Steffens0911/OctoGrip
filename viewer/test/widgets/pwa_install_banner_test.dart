import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/widgets/pwa_install_banner.dart';

import '../helpers/pump_app.dart';

// PwaInstallBanner: StatefulWidget que envolve um filho.
// Em testes (kIsWeb = false) o banner nunca é exibido → apenas o filho aparece.
// Sem chamadas de API; _checkInstalled() retorna imediatamente quando !kIsWeb.

Widget _widget({Widget child = const Text('Conteúdo principal')}) => MaterialApp(
      home: Scaffold(
        body: PwaInstallBanner(child: child),
      ),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PwaInstallBanner — em ambiente não-web', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_widget());
      await tester.pumpAndSettle();

      expect(find.byType(PwaInstallBanner), findsOneWidget);
    });

    testWidgets('exibe o widget filho', (tester) async {
      await tester.pumpWidget(_widget(child: const Text('Conteúdo principal')));
      await tester.pumpAndSettle();

      expect(find.text('Conteúdo principal'), findsOneWidget);
    });

    testWidgets('não exibe banner de instalação fora da web', (tester) async {
      await tester.pumpWidget(_widget());
      await tester.pumpAndSettle();

      // Fora da web, o banner nunca deve aparecer
      expect(find.textContaining('Instalar'), findsNothing);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_widget());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
