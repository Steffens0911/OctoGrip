import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/academy/academy_attendance_hub_screen.dart';

import '../helpers/pump_app.dart';

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting(user: stubStudent(role: 'professor'));
  });

  tearDown(() {
    clearAuthForTesting();
  });

  group('AcademyAttendanceHubScreen', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AcademyAttendanceHubScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AcademyAttendanceHubScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Chamada e frequência"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AcademyAttendanceHubScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Chamada'), findsWidgets);
    });

    testWidgets('exibe opção de Chamada (QR)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AcademyAttendanceHubScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Chamada (QR)'), findsWidgets);
    });

    testWidgets('exibe opção de Histórico de chamadas', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AcademyAttendanceHubScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Histórico'), findsWidgets);
    });
  });
}
