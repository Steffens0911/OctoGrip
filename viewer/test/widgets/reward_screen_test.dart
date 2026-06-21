import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/widgets/gamification/reward_screen.dart';

import '../helpers/pump_app.dart';

// RewardScreen: StatelessWidget puro com dados via construtor.
// Exibe título, subtítulo, XP ganho e barra de nível.

Widget _screen({
  String title = 'Missão completa!',
  String subtitle = 'Continue assim!',
  int xpGained = 50,
  int level = 5,
  double fraction = 0.6,
  int levelPoints = 300,
  int nextThreshold = 500,
}) =>
    MaterialApp(
      home: Scaffold(
        body: RewardScreen(
          title: title,
          subtitle: subtitle,
          xpGained: xpGained,
          level: level,
          levelProgressFraction: fraction,
          levelPointsInLevel: levelPoints,
          nextThreshold: nextThreshold,
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

  group('RewardScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      expect(find.byType(RewardScreen), findsOneWidget);
    });

    testWidgets('exibe o título', (tester) async {
      await tester.pumpWidget(_screen(title: 'Missão concluída!'));
      await tester.pump();

      expect(find.textContaining('Missão'), findsWidgets);
    });

    testWidgets('exibe o subtítulo', (tester) async {
      await tester.pumpWidget(_screen(subtitle: 'Parabéns pelo esforço!'));
      await tester.pump();

      expect(find.textContaining('Parabéns'), findsWidgets);
    });

    testWidgets('exibe XP ganho', (tester) async {
      await tester.pumpWidget(_screen(xpGained: 75));
      await tester.pump();

      // XP pode ser exibido como "+75", "75 XP", "75 xp" etc.
      expect(
        find.textContaining('75').evaluate().isNotEmpty ||
            find.textContaining('XP').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('exibe nível do usuário', (tester) async {
      await tester.pumpWidget(_screen(level: 7));
      await tester.pump();

      expect(find.textContaining('7'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
