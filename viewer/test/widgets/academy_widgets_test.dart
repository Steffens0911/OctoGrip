import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/training_stats.dart';
import 'package:viewer/widgets/academy_login_notice_dialog.dart';
import 'package:viewer/widgets/student/student_stats_section.dart';

import '../helpers/pump_app.dart';

// AcademyLoginNoticeDialog: AlertDialog simples com título/corpo, sem API.
// StudentStatsSection: StatelessWidget com TrainingStats, sem API.

TrainingStats _stats({
  int workouts = 5,
  int positions = 20,
  int positionsTotal = 100,
  int videos = 3,
  int? daysSince,
}) =>
    TrainingStats(
      workoutsLast30Days: workouts,
      positionsLast30Days: positions,
      positionsTotal: positionsTotal,
      videosLast30Days: videos,
      daysSinceLastWorkout: daysSince,
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AcademyLoginNoticeDialog', () {
    testWidgets('exibe título padrão quando titleText nulo', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showDialog(
                context: ctx,
                builder: (_) => const AcademyLoginNoticeDialog(
                  titleText: null,
                  bodyText: 'Corpo da mensagem.',
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Aviso'), findsWidgets);
    });

    testWidgets('exibe título customizado', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showDialog(
                context: ctx,
                builder: (_) => const AcademyLoginNoticeDialog(
                  titleText: 'Atenção alunos',
                  bodyText: 'Mensagem importante.',
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Atenção alunos'), findsWidgets);
    });

    testWidgets('exibe corpo da mensagem', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showDialog(
                context: ctx,
                builder: (_) => const AcademyLoginNoticeDialog(
                  titleText: 'Título',
                  bodyText: 'Academia fechada amanhã.',
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('fechada'), findsWidgets);
    });
  });

  group('StudentStatsSection', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudentStatsSection(stats: _stats()),
        ),
      ));
      await tester.pump();

      expect(find.byType(StudentStatsSection), findsOneWidget);
    });

    testWidgets('exibe "Hoje!" quando daysSinceLastWorkout é 0', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudentStatsSection(stats: _stats(daysSince: 0)),
        ),
      ));
      await tester.pump();

      expect(find.textContaining('Hoje'), findsWidgets);
    });

    testWidgets('exibe pontuação de pontualidade quando fornecida', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudentStatsSection(
            stats: _stats(),
            punctualityStreak: 5,
            punctualityStreakBest: 10,
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(StudentStatsSection), findsOneWidget);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudentStatsSection(stats: _stats()),
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
