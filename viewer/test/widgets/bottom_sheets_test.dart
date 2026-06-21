import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/widgets/gamification/points_rules_sheet.dart';
import 'package:viewer/widgets/student/student_rules_sheet.dart';

import '../helpers/pump_app.dart';

// showPointsRulesSheet e showStudentRulesSheet:
// Funções que abrem ModalBottomSheet com conteúdo estático.
// Testadas montando um botão que dispara a função e verificando o conteúdo do sheet.

Widget _pointsRulesHost() => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showPointsRulesSheet(ctx),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

Widget _studentRulesHost() => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showStudentRulesSheet(ctx),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('showPointsRulesSheet', () {
    testWidgets('abre bottom sheet ao tocar no botão', (tester) async {
      await tester.pumpWidget(_pointsRulesHost());
      await tester.pump();

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('exibe conteúdo de pontos no sheet', (tester) async {
      await tester.pumpWidget(_pointsRulesHost());
      await tester.pump();

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // O sheet exibe algum texto sobre pontos/XP
      expect(
        find.textContaining('pont').evaluate().isNotEmpty ||
            find.textContaining('XP').evaluate().isNotEmpty ||
            find.textContaining('Ponto').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('showStudentRulesSheet', () {
    testWidgets('abre bottom sheet ao tocar no botão', (tester) async {
      await tester.pumpWidget(_studentRulesHost());
      await tester.pump();

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('exibe título "Regras do aluno"', (tester) async {
      await tester.pumpWidget(_studentRulesHost());
      await tester.pump();

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Regras'), findsWidgets);
    });

    testWidgets('exibe pelo menos uma regra', (tester) async {
      await tester.pumpWidget(_studentRulesHost());
      await tester.pump();

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Regra'), findsWidgets);
    });
  });
}
