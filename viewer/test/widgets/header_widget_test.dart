import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/widgets/header_widget.dart';

import '../helpers/pump_app.dart';

// HeaderWidget: StatelessWidget puro com dados via construtor.
// Exibe saudação, nível, XP, nome da academia e badge do vídeo diário.

Widget _widget({
  String userName = 'João',
  String userBelt = 'Azul',
  int userLevel = 3,
  int currentXp = 150,
  int maxXp = 500,
  String? academyName,
  int dailyVideoPoints = 30,
  bool dailyVideoCompleted = false,
}) =>
    MaterialApp(
      home: Scaffold(
        body: HeaderWidget(
          userName: userName,
          userBelt: userBelt,
          userLevel: userLevel,
          currentXp: currentXp,
          maxXp: maxXp,
          academyName: academyName,
          dailyVideoPoints: dailyVideoPoints,
          dailyVideoCompleted: dailyVideoCompleted,
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

  group('HeaderWidget — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_widget());
      await tester.pump();

      expect(find.byType(HeaderWidget), findsOneWidget);
    });

    testWidgets('exibe nome do usuário', (tester) async {
      await tester.pumpWidget(_widget(userName: 'Carlos Silva'));
      await tester.pump();

      expect(find.textContaining('Carlos'), findsWidgets);
    });

    testWidgets('exibe faixa do usuário', (tester) async {
      await tester.pumpWidget(_widget(userBelt: 'Roxa'));
      await tester.pump();

      expect(find.textContaining('Roxa'), findsWidgets);
    });

    testWidgets('exibe badge de tarefa diária pendente', (tester) async {
      await tester.pumpWidget(_widget(
        dailyVideoPoints: 30,
        dailyVideoCompleted: false,
      ));
      await tester.pump();

      expect(find.textContaining('XP'), findsWidgets);
    });

    testWidgets('exibe badge de tarefa concluída', (tester) async {
      await tester.pumpWidget(_widget(dailyVideoCompleted: true));
      await tester.pump();

      expect(find.textContaining('concluída').evaluate().isNotEmpty ||
          find.textContaining('Tarefa').evaluate().isNotEmpty, isTrue);
    });

    testWidgets('exibe nome da academia quando fornecido', (tester) async {
      await tester.pumpWidget(_widget(academyName: 'Academia Teste'));
      await tester.pump();

      expect(find.textContaining('Academia Teste'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_widget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
