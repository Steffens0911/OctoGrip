import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/widgets/app_list_scaffold.dart';
import 'package:viewer/widgets/game_background.dart';

import '../helpers/pump_app.dart';

// AppListScaffold e GameBackground: widgets de layout sem API calls.

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppListScaffold', () {
    testWidgets('renderiza sem crash com lista vazia', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AppListScaffold(children: [])),
      ));
      await tester.pump();

      expect(find.byType(AppListScaffold), findsOneWidget);
    });

    testWidgets('exibe filhos fornecidos', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AppListScaffold(
            children: [
              Text('Item A'),
              Text('Item B'),
            ],
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Item A'), findsOneWidget);
      expect(find.text('Item B'), findsOneWidget);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AppListScaffold(
            children: [Text('Conteúdo')],
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('GameBackground', () {
    testWidgets('renderiza sem crash sem filho', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: GameBackground()),
      ));
      await tester.pump();

      expect(find.byType(GameBackground), findsOneWidget);
    });

    testWidgets('renderiza com filho', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: GameBackground(child: Text('Conteúdo do jogo')),
        ),
      ));
      await tester.pump();

      expect(find.byType(GameBackground), findsOneWidget);
      expect(find.text('Conteúdo do jogo'), findsOneWidget);
    });
  });
}
