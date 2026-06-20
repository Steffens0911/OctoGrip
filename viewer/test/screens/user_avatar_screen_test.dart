import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/student/user_avatar_screen.dart';

import '../helpers/pump_app.dart';

// UserAvatarScreen: sem chamadas de API no init, apenas lê o usuário em cache.
// Tem Row com botões que overflow no viewport padrão → usa 1200×800.

Widget _screen() => const MaterialApp(home: UserAvatarScreen());

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting();
  });

  tearDown(() {
    clearAuthForTesting();
  });

  group('UserAvatarScreen', () {
    testWidgets('renderiza sem crash', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(UserAvatarScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Fotos"', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Fotos'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('exibe seção Foto de perfil', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Foto de perfil'), findsWidgets);
    });
  });
}
