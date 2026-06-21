import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/widgets/app_error_message.dart';
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
