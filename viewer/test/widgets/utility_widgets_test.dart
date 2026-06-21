import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/widgets/app_error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';
import 'package:viewer/widgets/bottom_navigation_widget.dart';
import 'package:viewer/widgets/schedule_card.dart';
import 'package:viewer/widgets/today_academy_card.dart';

import '../helpers/pump_app.dart';

// Widgets utilitários puros (StatelessWidget, sem API calls).

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppFeedback.show', () {
    testWidgets('exibe SnackBar de sucesso com mensagem', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => AppFeedback.show(
                ctx,
                message: 'Salvo com sucesso!',
                type: AppFeedbackType.success,
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Abrir'));
      await tester.pump();

      expect(find.text('Salvo com sucesso!'), findsOneWidget);
    });

    testWidgets('exibe SnackBar de erro', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => AppFeedback.show(
                ctx,
                message: 'Ocorreu um erro!',
                type: AppFeedbackType.error,
              ),
              child: const Text('Erro'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Erro'));
      await tester.pump();

      expect(find.text('Ocorreu um erro!'), findsOneWidget);
    });

    testWidgets('exibe SnackBar de warning', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => AppFeedback.show(
                ctx,
                message: 'Atenção!',
                type: AppFeedbackType.warning,
              ),
              child: const Text('Aviso'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Aviso'));
      await tester.pump();

      expect(find.text('Atenção!'), findsOneWidget);
    });

    testWidgets('exibe SnackBar de info', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => AppFeedback.show(
                ctx,
                message: 'Informação',
                type: AppFeedbackType.info,
              ),
              child: const Text('Info'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Info'));
      await tester.pump();

      expect(find.text('Informação'), findsOneWidget);
    });
  });

  group('AppErrorMessage', () {
    testWidgets('renderiza com mensagem de erro', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AppErrorMessage(message: 'Ocorreu um erro!')),
      ));
      await tester.pump();

      expect(find.byType(AppErrorMessage), findsOneWidget);
      expect(find.textContaining('Ocorreu um erro!'), findsWidgets);
    });
  });

  group('AppStandardAppBar', () {
    testWidgets('renderiza com título', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          appBar: AppStandardAppBar(title: 'Minha Tela'),
          body: SizedBox(),
        ),
      ));
      await tester.pump();

      expect(find.byType(AppStandardAppBar), findsOneWidget);
      expect(find.text('Minha Tela'), findsOneWidget);
    });

    testWidgets('renderiza com subtítulo', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          appBar: AppStandardAppBar(title: 'Tela', subtitle: 'Subtítulo'),
          body: SizedBox(),
        ),
      ));
      await tester.pump();

      expect(find.text('Subtítulo'), findsOneWidget);
    });
  });

  group('BottomNavigationWidget', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: const SizedBox(),
          bottomNavigationBar: BottomNavigationWidget(
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(BottomNavigationWidget), findsOneWidget);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNavigationWidget(
            currentIndex: 1,
            onTap: (_) {},
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ScheduleCard', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ScheduleCard(onTap: () {})),
      ));
      await tester.pump();

      expect(find.byType(ScheduleCard), findsOneWidget);
    });

    testWidgets('exibe título padrão', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ScheduleCard(onTap: () {})),
      ));
      await tester.pump();

      expect(find.textContaining('Horários'), findsWidgets);
    });

    testWidgets('exibe título customizado', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ScheduleCard(title: 'Aulas da semana', onTap: () {}),
        ),
      ));
      await tester.pump();

      expect(find.textContaining('Aulas da semana'), findsWidgets);
    });
  });

  group('TodayAcademyCard', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: TodayAcademyCard()),
      ));
      await tester.pump();

      expect(find.byType(TodayAcademyCard), findsOneWidget);
    });

    testWidgets('exibe título padrão', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: TodayAcademyCard()),
      ));
      await tester.pump();

      expect(find.textContaining('Mural'), findsWidgets);
    });

    testWidgets('exibe título customizado', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: TodayAcademyCard(title: 'Pensamento do dia')),
      ));
      await tester.pump();

      expect(find.textContaining('Pensamento do dia'), findsWidgets);
    });
  });
}
