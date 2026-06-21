import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/student/training_videos_section.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// TrainingVideosSection: StatefulWidget; initState → GET /me/training_videos/today.
// Lista vazia + sem academyId → "Vincule-se a uma academia".
// Lista vazia + com academyId → "Nenhum vídeo disponível hoje".
// Erro → "Tentar novamente".

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Widget _screen() => const MaterialApp(
      home: Scaffold(body: TrainingVideosSection()),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('TrainingVideosSection — sem academia', () {
    testWidgets('exibe mensagem de vincular academia quando usuário sem academyId', (tester) async {
      setAuthForTesting(user: stubStudent(role: 'aluno'));
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('academia'), findsWidgets);
    });

    testWidgets('renderiza sem crash', (tester) async {
      setAuthForTesting(user: stubStudent(role: 'aluno'));
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(TrainingVideosSection), findsOneWidget);
    });
  });

  group('TrainingVideosSection — erro de rede', () {
    testWidgets('exibe botão tentar novamente em erro 500', (tester) async {
      setAuthForTesting();
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json({'detail': 'Erro'}, 500));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Tentar novamente'), findsWidgets);
    });
  });
}
