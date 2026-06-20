import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/student/lesson_view_data.dart';
import 'package:viewer/screens/student/lesson_view_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/pump_app.dart';

// LessonViewScreen evita chamadas de API quando:
//   - alreadyCompleted: true  → pula _fetchLessonCompletedStatus
//   - academyId: null          → pula _fetchPendingExecution
// Usa YoutubePlayerEmbed → 'Sem vídeo' quando videoUrl vazio.

LessonViewData _data({
  String title = 'Triângulo Frontal',
  String description = 'Aplique o triângulo a partir da guarda fechada.',
  String videoUrl = '',
  String? lessonId,
  String? missionId,
  bool alreadyCompleted = true,
}) =>
    LessonViewData(
      userId: 'u1',
      title: title,
      description: description,
      videoUrl: videoUrl,
      lessonId: lessonId,
      missionId: missionId,
      academyId: null,
      alreadyCompleted: alreadyCompleted,
    );

Widget _screen({LessonViewData? data}) => MaterialApp(
      home: LessonViewScreen(data: data ?? _data()),
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

  group('LessonViewScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(LessonViewScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Lição"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Lição'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('LessonViewScreen — conteúdo', () {
    testWidgets('exibe título da lição', (tester) async {
      await tester.pumpWidget(
        _screen(data: _data(title: 'Raspagem de Tesoura')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Raspagem de Tesoura'), findsWidgets);
    });

    testWidgets('exibe descrição da lição', (tester) async {
      await tester.pumpWidget(
        _screen(data: _data(description: 'Execute a posição lateral corretamente.')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Execute a posição'), findsWidgets);
    });

    testWidgets('exibe chip "Modo Reels"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Reels'), findsWidgets);
    });
  });

  group('LessonViewScreen — estado do botão', () {
    testWidgets('exibe botão "Lição concluída" quando já concluída', (tester) async {
      await tester.pumpWidget(
        _screen(
          data: _data(lessonId: 'ls1', alreadyCompleted: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('concluída'), findsWidgets);
    });

    testWidgets('não exibe botão Concluir quando lessonId e missionId são nulos',
        (tester) async {
      await tester.pumpWidget(
        _screen(data: _data(lessonId: null, missionId: null)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Concluir'), findsNothing);
    });
  });
}
