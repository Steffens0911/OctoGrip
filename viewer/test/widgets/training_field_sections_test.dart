import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/widgets/academy/training_field_sections.dart';

import '../helpers/pump_app.dart';

// AcademyTrainingFieldSections: StatelessWidget com callbacks e filhos.
// Sem API calls; exibe seções expandíveis de técnicas e troféus.

Widget _screen() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AcademyTrainingFieldSections(
            onOpenTechniques: () async {},
            onOpenTrophies: () {},
            hasActiveTurmas: true,
            onWeeklyKitsExpansionChanged: (_) {},
            weeklyKitsChildren: const [Text('Turma A')],
            weeklyMissionsChildren: const [Text('Missão 1')],
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

  group('AcademyTrainingFieldSections', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      expect(find.byType(AcademyTrainingFieldSections), findsOneWidget);
    });

    testWidgets('exibe seção de técnicas', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      expect(find.textContaining('técnicas').evaluate().isNotEmpty ||
          find.textContaining('Posições').evaluate().isNotEmpty, isTrue);
    });

    testWidgets('exibe seção de troféus', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      expect(find.textContaining('Troféu').evaluate().isNotEmpty ||
          find.textContaining('trofé').evaluate().isNotEmpty, isTrue);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
