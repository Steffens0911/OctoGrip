import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/academy/manual_trophy_template_form_screen.dart';

import '../helpers/pump_app.dart';

// ManualTrophyTemplateFormScreen: sem chamadas de API no init.
// Apenas lê widget.existing para pré-preencher os campos.

Widget _screen({String trophyType = 'custom'}) => MaterialApp(
      home: ManualTrophyTemplateFormScreen(
        academyId: 'ac1',
        trophyType: trophyType,
      ),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting(user: stubStudent(role: 'professor'));
  });

  tearDown(() {
    clearAuthForTesting();
  });

  group('ManualTrophyTemplateFormScreen — tipo custom', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(ManualTrophyTemplateFormScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Novo troféu"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('troféu'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('exibe campo Nome', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Nome'), findsWidgets);
    });
  });

  group('ManualTrophyTemplateFormScreen — tipo championship', () {
    testWidgets('exibe AppBar "Novo modelo de medalha"', (tester) async {
      await tester.pumpWidget(_screen(trophyType: 'championship'));
      await tester.pumpAndSettle();

      expect(find.textContaining('medalha'), findsWidgets);
    });
  });
}
