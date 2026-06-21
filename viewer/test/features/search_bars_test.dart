import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/techniques/presentation/widgets/technique_search_bar.dart';
import 'package:viewer/features/trophies/presentation/widgets/trophy_search_bar.dart';

import '../helpers/pump_app.dart';

// Testes de widget para TechniqueSearchBar e TrophySearchBar.

void main() {
  setUpAll(disableGoogleFontsFetch);

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('TechniqueSearchBar', () {
    testWidgets('renderiza campo de busca com hint', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(wrap(TechniqueSearchBar(
        controller: ctrl,
        onChanged: (_) {},
      )));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Buscar por nome da técnica'), findsOneWidget);
    });

    testWidgets('chama onChanged ao digitar', (tester) async {
      final ctrl = TextEditingController();
      String? last;
      await tester.pumpWidget(wrap(TechniqueSearchBar(
        controller: ctrl,
        onChanged: (v) => last = v,
      )));

      await tester.enterText(find.byType(TextField), 'arm');
      await tester.pump();

      expect(last, 'arm');
    });

    testWidgets('exibe botão clear quando há texto', (tester) async {
      final ctrl = TextEditingController(text: 'abc');
      await tester.pumpWidget(wrap(TechniqueSearchBar(
        controller: ctrl,
        onChanged: (_) {},
      )));
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('não exibe clear quando campo vazio', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(wrap(TechniqueSearchBar(
        controller: ctrl,
        onChanged: (_) {},
      )));
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('clicar em clear limpa o campo e chama onClear', (tester) async {
      final ctrl = TextEditingController(text: 'xpto');
      bool cleared = false;
      await tester.pumpWidget(wrap(TechniqueSearchBar(
        controller: ctrl,
        onChanged: (_) {},
        onClear: () => cleared = true,
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(cleared, isTrue);
      expect(ctrl.text, isEmpty);
    });

    testWidgets('trocar controller reconecta listener', (tester) async {
      final ctrl1 = TextEditingController();
      final ctrl2 = TextEditingController();
      String? last;

      await tester.pumpWidget(wrap(TechniqueSearchBar(
        controller: ctrl1,
        onChanged: (v) => last = v,
      )));
      await tester.pump();

      // Substitui controller via rebuild
      await tester.pumpWidget(wrap(TechniqueSearchBar(
        controller: ctrl2,
        onChanged: (v) => last = v,
      )));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'novo');
      await tester.pump();

      expect(last, 'novo');
    });
  });

  group('TrophySearchBar', () {
    testWidgets('renderiza campo de busca com hint', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(wrap(TrophySearchBar(
        controller: ctrl,
        onChanged: (_) {},
      )));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Buscar por nome do troféu'), findsOneWidget);
    });

    testWidgets('chama onClear ao clicar no botão X', (tester) async {
      final ctrl = TextEditingController(text: 'abc');
      bool cleared = false;
      await tester.pumpWidget(wrap(TrophySearchBar(
        controller: ctrl,
        onChanged: (_) {},
        onClear: () => cleared = true,
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(cleared, isTrue);
      expect(ctrl.text, isEmpty);
    });
  });
}
