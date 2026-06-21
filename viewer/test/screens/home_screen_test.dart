import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/home_screen.dart';

import '../helpers/pump_app.dart';

// HomeScreen: StatelessWidget puro sem API calls nem estado.
// Exibe logo, nome do app e instrução de menu.

Widget _screen() => const MaterialApp(home: HomeScreen());

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HomeScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('exibe instrução sobre o menu', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      expect(find.textContaining('menu'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
