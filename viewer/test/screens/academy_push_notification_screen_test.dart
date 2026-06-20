import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/academy/academy_push_notification_screen.dart';

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

  group('AcademyPushNotificationScreen', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AcademyPushNotificationScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AcademyPushNotificationScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Aviso à academia"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AcademyPushNotificationScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Aviso'), findsWidgets);
    });

    testWidgets('exibe campo Título', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AcademyPushNotificationScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Título'), findsWidgets);
    });

    testWidgets('exibe campo Mensagem', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AcademyPushNotificationScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Mensagem'), findsWidgets);
    });

    testWidgets('exibe botão de envio de notificação', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AcademyPushNotificationScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('notificação'), findsWidgets);
    });
  });
}
