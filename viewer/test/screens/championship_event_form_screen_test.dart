import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/academy/championship_event_form_screen.dart';

import '../helpers/pump_app.dart';

// ChampionshipEventFormScreen: sem chamadas de API no initState.
// Apenas monta o formulário com campos de texto e seletor de data.

Widget _screen() => const MaterialApp(
      home: ChampionshipEventFormScreen(academyId: 'ac1'),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ChampionshipEventFormScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(ChampionshipEventFormScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Novo Campeonato"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Campeonato'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ChampionshipEventFormScreen — campos do formulário', () {
    testWidgets('exibe campo "Nome do campeonato"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Nome do campeonato'), findsWidgets);
    });

    testWidgets('exibe campo "Local (opcional)"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Local'), findsWidgets);
    });

    testWidgets('exibe campo de data do evento', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Data'), findsWidgets);
    });

    testWidgets('exibe botão "Criar campeonato"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Criar'), findsWidgets);
    });
  });
}
