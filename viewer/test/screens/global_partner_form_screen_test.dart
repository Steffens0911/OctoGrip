import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/admin/global_partner_form_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/pump_app.dart';

// GlobalPartnerFormScreen: sem chamadas de API no initState.
// Apenas lê widget.partner para pré-preencher campos.

Widget _screen() => const MaterialApp(
      home: GlobalPartnerFormScreen(),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
  });

  group('GlobalPartnerFormScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(GlobalPartnerFormScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Novo parceiro global"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('parceiro global'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('GlobalPartnerFormScreen — campos do formulário', () {
    testWidgets('exibe campo Nome', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Nome'), findsWidgets);
    });

    testWidgets('exibe campo Link externo', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Link externo'), findsWidgets);
    });

    testWidgets('exibe switch Ativo', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('exibe botão Criar', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Criar'), findsWidgets);
    });
  });
}
