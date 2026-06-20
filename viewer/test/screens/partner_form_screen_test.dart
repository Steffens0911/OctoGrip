import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/admin/partner_form_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/pump_app.dart';

// PartnerFormScreen: sem chamadas de API no initState.
// Só lê widget.partner para pré-preencher campos.

Widget _screen() => MaterialApp(
      home: PartnerFormScreen(
        academy: Academy(id: 'ac1', name: 'Academia Teste'),
      ),
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

  group('PartnerFormScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(PartnerFormScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Novo parceiro"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('parceiro'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('PartnerFormScreen — campos do formulário', () {
    testWidgets('exibe campo Nome', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Nome'), findsWidgets);
    });

    testWidgets('exibe campo Descrição', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Descrição'), findsWidgets);
    });

    testWidgets('exibe campo URL', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('URL'), findsWidgets);
    });

    testWidgets('exibe botão Criar', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Criar'), findsWidgets);
    });
  });
}
