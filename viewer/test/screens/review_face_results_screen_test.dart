import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/academy/review_face_results_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// ReviewFaceResultsScreen: initState → GET /face-recognition/job/{jobId}.
// Se retorna 'pending'/'processing': inicia timer de polling (problemático em testes).
// Se retorna erro (500): apenas seta _error sem iniciar timer.
// Testamos só o caminho de erro 500 para evitar o polling timer.

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Widget _screen() => const MaterialApp(
      home: ReviewFaceResultsScreen(
        sessionId: 'sess-001',
        jobId: 'job-001',
        academyId: 'ac1',
      ),
    );

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting(user: stubStudent(role: 'professor'));
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('ReviewFaceResultsScreen — AppBar', () {
    testWidgets('renderiza sem crash com erro 500', (tester) async {
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

      expect(find.byType(ReviewFaceResultsScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Revisar reconhecimento"', (tester) async {
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

      expect(find.textContaining('reconhecimento'), findsWidgets);
    });
  });

  group('ReviewFaceResultsScreen — erro de rede', () {
    testWidgets('erro 500 exibe estado de erro', (tester) async {
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

      expect(find.byType(ReviewFaceResultsScreen), findsOneWidget);
      // AppScreenState.error exibe botão de retry ou mensagem de erro
      expect(
        find.textContaining('novamente').evaluate().isNotEmpty ||
            find.textContaining('Erro').evaluate().isNotEmpty ||
            find.textContaining('Não foi').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
