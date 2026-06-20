import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/student/report_difficulty_screen.dart';

import '../helpers/pump_app.dart';

// ReportDifficultyScreen não faz chamadas de API no init.
// Com academyId → exibe formulário; sem academyId → exibe mensagem de erro.

Widget _screen({String? academyId}) => MaterialApp(
      home: ReportDifficultyScreen(
        userId: 'u-test',
        academyId: academyId,
      ),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting();
  });

  tearDown(() {
    clearAuthForTesting();
  });

  group('ReportDifficultyScreen — com academia', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen(academyId: 'ac1'));
      await tester.pumpAndSettle();

      expect(find.byType(ReportDifficultyScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Reportar dificuldade"', (tester) async {
      await tester.pumpWidget(_screen(academyId: 'ac1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Reportar'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_screen(academyId: 'ac1'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('exibe campo de descrição da dificuldade', (tester) async {
      await tester.pumpWidget(_screen(academyId: 'ac1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('dificuldade'), findsWidgets);
    });

    testWidgets('exibe botão Enviar', (tester) async {
      await tester.pumpWidget(_screen(academyId: 'ac1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Enviar'), findsWidgets);
    });
  });

  group('ReportDifficultyScreen — sem academia', () {
    testWidgets('exibe aviso quando não há academyId', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('academia'), findsWidgets);
    });
  });
}
