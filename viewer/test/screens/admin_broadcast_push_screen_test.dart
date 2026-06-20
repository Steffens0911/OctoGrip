import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/admin/admin_broadcast_push_screen.dart';
import 'package:viewer/services/auth_service.dart';

import '../helpers/pump_app.dart';

// AdminBroadcastPushScreen usa RoleGuard → precisa de ChangeNotifierProvider<AuthService>.
Widget _screen() => ChangeNotifierProvider<AuthService>.value(
      value: AuthService(),
      child: const MaterialApp(home: AdminBroadcastPushScreen()),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting(user: stubStudent(role: 'administrador'));
  });

  tearDown(() {
    clearAuthForTesting();
  });

  group('AdminBroadcastPushScreen', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(AdminBroadcastPushScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Push global"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Push global'), findsWidgets);
    });

    testWidgets('exibe campo Título', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Título'), findsWidgets);
    });

    testWidgets('exibe campo Mensagem', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Mensagem'), findsWidgets);
    });

    testWidgets('exibe botão de envio', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('enviar'), findsWidgets);
    });
  });
}
