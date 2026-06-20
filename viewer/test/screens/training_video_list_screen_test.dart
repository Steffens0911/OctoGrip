import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/admin/training_video_list_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _videoJson({
  String id = 'v1',
  String title = 'Triângulo Frontal',
  String youtubeUrl = 'https://youtu.be/abc',
  int pointsPerDay = 10,
  bool isActive = true,
  String? academyId,
}) =>
    {
      'id': id,
      'title': title,
      'youtube_url': youtubeUrl,
      'points_per_day': pointsPerDay,
      'is_active': isActive,
      'academy_id': academyId,
      'has_completed_today': false,
    };

Widget _screen({bool localOnly = false}) => MaterialApp(
      home: TrainingVideoListScreen(localOnly: localOnly),
    );

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // professor: não é admin → todos os vídeos retornados pela API são exibidos
    setAuthForTesting(user: stubStudent(role: 'professor'));
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('TrainingVideoListScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(TrainingVideoListScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar com título correto', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Vídeos'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator após carregar',
        (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('TrainingVideoListScreen — conteúdo', () {
    testWidgets('exibe título do vídeo retornado pela API', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
          (_) async =>
              _json([_videoJson(title: 'Triângulo Frontal')]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Triângulo'), findsWidgets);
    });

    testWidgets('exibe dois vídeos distintos', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
          (_) async => _json([
                _videoJson(id: 'v1', title: 'Mata-Leão'),
                _videoJson(id: 'v2', title: 'Armlock'),
              ]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Mata-Leão'), findsWidgets);
      expect(find.textContaining('Armlock'), findsWidgets);
    });

    testWidgets('estado vazio exibe mensagem orientativa', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Nenhum'), findsWidgets);
    });
  });

  group('TrainingVideoListScreen — erro de rede', () {
    testWidgets('erro 500 não trava a tela', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                '{"detail": "Erro interno"}',
                500,
                headers: {'content-type': 'application/json'},
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(TrainingVideoListScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
