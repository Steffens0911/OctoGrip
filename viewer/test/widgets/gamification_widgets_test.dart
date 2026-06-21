import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/widgets/gamification/streak_widget.dart';
import 'package:viewer/widgets/gamification/xp_bar.dart';
import 'package:viewer/widgets/trophies_home_section.dart';

import '../helpers/pump_app.dart';

// StreakWidget: StatelessWidget — dados via construtor.
// XPBar: StatelessWidget — dados via construtor.
// TrophiesHomeSection: StatelessWidget — dados via construtor, sem API.

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StreakWidget', () {
    testWidgets('renderiza sem crash sem streakDays (sem exibição)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StreakWidget()),
      ));
      await tester.pump();

      expect(find.byType(StreakWidget), findsOneWidget);
    });

    testWidgets('exibe dias de sequência quando fornecido', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StreakWidget(streakDays: 7)),
      ));
      await tester.pump();

      expect(find.textContaining('7'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StreakWidget(streakDays: 3)),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('XPBar', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: XPBar(progress: 0.5)),
      ));
      await tester.pump();

      expect(find.byType(XPBar), findsOneWidget);
    });

    testWidgets('exibe label de incremento quando fornecido', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: XPBar(progress: 0.3, incrementLabel: '+25 XP')),
      ));
      await tester.pump();

      expect(find.textContaining('25 XP'), findsWidgets);
    });

    testWidgets('exibe label de nível quando fornecido', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: XPBar(progress: 0.8, levelLabel: 'Nível 4')),
      ));
      await tester.pump();

      expect(find.textContaining('Nível 4'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: XPBar(progress: 1.0)),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('TrophiesHomeSection', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TrophiesHomeSection(onOpenGallery: () {}),
        ),
      ));
      await tester.pump();

      expect(find.byType(TrophiesHomeSection), findsOneWidget);
    });

    testWidgets('exibe título "Troféus"', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TrophiesHomeSection(onOpenGallery: () {}),
        ),
      ));
      await tester.pump();

      expect(find.textContaining('Troféu'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TrophiesHomeSection(onOpenGallery: () {}),
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
