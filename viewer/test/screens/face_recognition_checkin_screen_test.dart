import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/academy/face_recognition_checkin_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/pump_app.dart';

// FaceRecognitionCheckinScreen: sem API calls no initState.
// Exibe botão de seleção de foto e botão de envio (desabilitado até foto selecionada).

Widget _screen() => const MaterialApp(
      home: FaceRecognitionCheckinScreen(sessionId: 'session-001'),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting();
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('FaceRecognitionCheckinScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(FaceRecognitionCheckinScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Chamada por foto"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('foto'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator no init', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('FaceRecognitionCheckinScreen — botões', () {
    testWidgets('exibe botão de selecionar foto', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Selecionar'), findsWidgets);
    });

    testWidgets('exibe botão Enviar desabilitado sem foto', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Enviar'), findsWidgets);
      // Botão desabilitado pois _photoBytes == null
      final btn = tester.widget<FilledButton>(
        find.ancestor(
          of: find.textContaining('Enviar'),
          matching: find.byType(FilledButton),
        ).first,
      );
      expect(btn.onPressed, isNull);
    });
  });
}
