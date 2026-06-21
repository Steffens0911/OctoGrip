import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/admin/lesson_list_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// LessonListScreen chama GET /lessons + GET /techniques em paralelo no initState.
// Usa AuthService().currentUser?.academyId e AuthService().canEditResources().

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _lessonJson({
  String id = 'ls1',
  String title = 'Triângulo de Costas',
}) =>
    {
      'id': id,
      'title': title,
      'slug': 'triangulo-de-costas',
      'order_index': 0,
      'technique_id': 't1',
      'academy_id': 'ac1',
      'video_url': null,
      'content': null,
      'technique_name': 'Triângulo',
      'position_name': null,
      'technique_video_url': null,
    };

http.Response _dispatch(Uri uri) {
  final path = uri.path;
  if (path.contains('/lessons')) return _json([]);
  if (path.contains('/techniques')) return _json([]);
  return _json({}, 404);
}

Widget _screen() => const MaterialApp(home: LessonListScreen());

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
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

  group('LessonListScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(LessonListScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Lições"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Lições'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator após carregar', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('LessonListScreen — estado vazio', () {
    testWidgets('exibe mensagem de lista vazia', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Nenhuma lição'), findsWidgets);
    });
  });

  group('LessonListScreen — com lições', () {
    testWidgets('exibe título da lição na lista', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        final path = (inv.positionalArguments[0] as Uri).path;
        if (path.contains('/lessons')) {
          return _json([_lessonJson(title: 'Chave de Tornozelo')]);
        }
        return _json([]);
      });
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Chave de Tornozelo'), findsWidgets);
    });
  });

  group('LessonListScreen — erro de rede', () {
    testWidgets('erro 500 exibe botão tentar novamente', (tester) async {
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

      expect(find.byType(LessonListScreen), findsOneWidget);
      expect(find.textContaining('Tentar novamente'), findsWidgets);
    });
  });
}
