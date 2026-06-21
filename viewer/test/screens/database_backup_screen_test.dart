import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/admin/database_backup_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';

import '../helpers/pump_app.dart';

// DatabaseBackupScreen usa RoleGuard → precisa de ChangeNotifierProvider<AuthService>.
// Sem chamadas de API no initState — apenas UI estática.

Widget _screen() => ChangeNotifierProvider<AuthService>.value(
      value: AuthService(),
      child: const MaterialApp(home: DatabaseBackupScreen()),
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
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('DatabaseBackupScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(DatabaseBackupScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar com título de Backup', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Backup'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('DatabaseBackupScreen — seção Exportar', () {
    testWidgets('exibe botão de backup completo ZIP', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('backup completo'), findsWidgets);
    });

    testWidgets('exibe botão de backup só SQL', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('SQL'), findsWidgets);
    });
  });

  group('DatabaseBackupScreen — seção Restaurar', () {
    testWidgets('exibe botão restaurar', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('restaurar'), findsWidgets);
    });

    testWidgets('exibe aviso sobre dados serem substituídos', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('apagados'), findsWidgets);
    });
  });
}
