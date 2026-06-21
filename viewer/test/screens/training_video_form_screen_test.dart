import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/admin/training_video_form_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/pump_app.dart';

// TrainingVideoFormScreen: sem chamadas de API no initState.
// initState apenas preenche controllers a partir de widget.video (null = novo).

Widget _screen() => const MaterialApp(home: TrainingVideoFormScreen());

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

  group('TrainingVideoFormScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(TrainingVideoFormScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Novo vídeo da tarefa diária"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('vídeo'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('TrainingVideoFormScreen — campos do formulário', () {
    testWidgets('exibe campo Título', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Título'), findsWidgets);
    });

    testWidgets('exibe campo Link do YouTube', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('YouTube'), findsWidgets);
    });

    testWidgets('exibe campo Pontos por dia', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Pontos'), findsWidgets);
    });

    testWidgets('exibe campo Duração em segundos', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Duração'), findsWidgets);
    });

    testWidgets('exibe switch Ativo', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('exibe botão Salvar', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Salvar'), findsWidgets);
    });
  });
}
