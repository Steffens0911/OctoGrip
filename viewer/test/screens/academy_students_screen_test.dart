import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/academy/academy_students_screen.dart';

import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Widget _screen() => MaterialApp(
      home: AcademyStudentsScreen(
        academy: Academy(id: 'ac1', name: 'Academia Teste'),
      ),
    );

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  group('AcademyStudentsScreen', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(AcademyStudentsScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Alunos"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Alunos'), findsWidgets);
    });

    testWidgets('exibe nome da academia no AppBar', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Academia Teste'), findsWidgets);
    });

    testWidgets('exibe opção de usuários da academia', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Usuários da academia'), findsWidgets);
    });

    testWidgets('exibe opção de editar pontos', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('pontos'), findsWidgets);
    });

    testWidgets('exibe opção de alunos ativos', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('ativos'), findsWidgets);
    });
  });
}
