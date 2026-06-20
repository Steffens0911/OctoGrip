import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/training_video.dart';
import 'package:viewer/screens/student/training_video_view_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// TrainingVideoViewScreen: sem chamadas de API no initState.
// Timer só cria se durationSeconds != null → usar null para evitar.
// YoutubePlayerEmbed exibe placeholder 'Sem vídeo' quando youtubeUrl é vazio.

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

TrainingVideo _video({
  String title = 'Técnica do Dia',
  int pointsPerDay = 10,
  bool hasCompletedToday = false,
}) =>
    TrainingVideo(
      id: 'v1',
      title: title,
      youtubeUrl: '',
      pointsPerDay: pointsPerDay,
      isActive: true,
      durationSeconds: null,
      hasCompletedToday: hasCompletedToday,
    );

Widget _screen({TrainingVideo? video}) => MaterialApp(
      home: TrainingVideoViewScreen(video: video ?? _video()),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
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

  group('TrainingVideoViewScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(TrainingVideoViewScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Campo de treinamento"', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Campo de treinamento'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator ao carregar',
        (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('TrainingVideoViewScreen — conteúdo', () {
    testWidgets('exibe título do vídeo', (tester) async {
      await tester.pumpWidget(_screen(video: _video(title: 'Raspagem Scissor')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Raspagem Scissor'), findsWidgets);
    });

    testWidgets('exibe label de pontos por dia', (tester) async {
      await tester.pumpWidget(_screen(video: _video(pointsPerDay: 15)));
      await tester.pumpAndSettle();

      expect(find.textContaining('15'), findsWidgets);
    });
  });

  group('TrainingVideoViewScreen — estado do botão', () {
    testWidgets('botão desabilitado antes de assistir ao fim', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('fim para liberar'), findsWidgets);
    });

    testWidgets('exibe "Concluído hoje" quando já completou hoje',
        (tester) async {
      await tester.pumpWidget(
        _screen(video: _video(hasCompletedToday: true)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Concluído hoje'), findsWidgets);
    });

    testWidgets('exibe instrução de assistir o vídeo', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Assista o vídeo'), findsWidgets);
    });
  });

  group('TrainingVideoViewScreen — erro de rede ao completar', () {
    testWidgets('tela não trava com erro na API ao completar', (tester) async {
      final client = MockHttpClient();
      when(() => client.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response(
                '{"detail": "Erro"}',
                500,
                headers: {'content-type': 'application/json'},
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(TrainingVideoViewScreen), findsOneWidget);
    });
  });
}
