import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/widgets/gamification/animated_button.dart';
import 'package:viewer/widgets/gamification/login_bonus_ring.dart';
import 'package:viewer/widgets/gamification/streak_widget.dart';
import 'package:viewer/widgets/student/home_loading_skeleton.dart';

import '../helpers/pump_app.dart';

// Widgets de gamificação e skeleton sem API calls.

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AnimatedButton', () {
    testWidgets('renderiza com filho', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnimatedButton(
            onPressed: () => pressed = true,
            child: const Text('Pressionar'),
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(AnimatedButton), findsOneWidget);
      expect(find.text('Pressionar'), findsOneWidget);
    });

    testWidgets('renderiza filho com onPressed ativo', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnimatedButton(
            onPressed: () {},
            child: const Text('Clique'),
          ),
        ),
      ));
      await tester.pump();

      // O widget deve exibir o filho
      expect(find.text('Clique'), findsOneWidget);
      expect(find.byType(AnimatedButton), findsOneWidget);
    });

    testWidgets('renderiza com onPressed nulo (desabilitado)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AnimatedButton(
            onPressed: null,
            child: Text('Desabilitado'),
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(AnimatedButton), findsOneWidget);
    });

    testWidgets('press e release disparam setState e AnimatedScale', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnimatedButton(
            onPressed: () {},
            child: const SizedBox(key: ValueKey('child'), width: 100, height: 50),
          ),
        ),
      ));
      await tester.pump();

      final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('child'))));
      await tester.pump();

      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedScale), findsOneWidget);
    });

    testWidgets('cancel do gesto redefine estado de pressed', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnimatedButton(
            onPressed: () {},
            child: const SizedBox(key: ValueKey('child2'), width: 100, height: 50),
          ),
        ),
      ));
      await tester.pump();

      final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('child2'))));
      await tester.pump();

      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedScale), findsOneWidget);
    });
  });

  group('LoginBonusRing', () {
    testWidgets('renderiza sem crash com streak 0', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: LoginBonusRing(streakDays: 0)),
      ));
      await tester.pump();

      expect(find.byType(LoginBonusRing), findsOneWidget);
    });

    testWidgets('renderiza com streak de 7 dias (ciclo completo)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: LoginBonusRing(streakDays: 7)),
      ));
      await tester.pump();

      expect(find.byType(LoginBonusRing), findsOneWidget);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: LoginBonusRing(streakDays: 3)),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('HomeHeaderLoadingSkeleton', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: HomeHeaderLoadingSkeleton()),
      ));
      await tester.pump();

      expect(find.byType(HomeHeaderLoadingSkeleton), findsOneWidget);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: HomeHeaderLoadingSkeleton()),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('streakProgressToNextBonus', () {
    test('retorna 0 para streak 0', () {
      expect(streakProgressToNextBonus(0), 0.0);
    });

    test('retorna 1.0 para múltiplo de 7 (ciclo completo)', () {
      expect(streakProgressToNextBonus(7), 1.0);
      expect(streakProgressToNextBonus(14), 1.0);
    });

    test('retorna fração para streak parcial', () {
      final progress = streakProgressToNextBonus(3);
      expect(progress, greaterThan(0.0));
      expect(progress, lessThan(1.0));
    });
  });
}
