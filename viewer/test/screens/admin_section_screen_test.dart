import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/admin/admin_section_screen.dart';
import 'package:viewer/services/auth_service.dart';

import '../helpers/pump_app.dart';

// AdminSectionScreen usa RoleGuard → precisa de ChangeNotifierProvider<AuthService>.
// Não tem Scaffold próprio — envolver com Scaffold no teste.
Widget _screen() => ChangeNotifierProvider<AuthService>.value(
      value: AuthService(),
      child: MaterialApp(
        home: Scaffold(
          body: const AdminSectionScreen(),
        ),
      ),
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

  group('AdminSectionScreen', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(AdminSectionScreen), findsOneWidget);
    });

    testWidgets('exibe título Admin', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Admin'), findsWidgets);
    });

    testWidgets('exibe tile Academias', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Academias'), findsWidgets);
    });

    testWidgets('exibe tile Usuários', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Usuários'), findsWidgets);
    });

    testWidgets('exibe tile Relatórios', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Relatórios'), findsWidgets);
    });
  });
}
