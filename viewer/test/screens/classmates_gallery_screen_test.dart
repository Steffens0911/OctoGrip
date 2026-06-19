import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/student/classmates_gallery_screen.dart';
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

Map<String, dynamic> _user({
  String id = 'u1',
  String name = 'Ana Costa',
  String graduation = 'blue',
}) =>
    {
      'id': id,
      'email': '$id@test.com',
      'name': name,
      'graduation': graduation,
      'role': 'aluno',
      'academy_id': 'ac1',
      'points_adjustment': 0,
      'login_streak_days': 0,
      'account_frozen': false,
      'gallery_visible': true,
    };

Map<String, dynamic> _trophyHomeSummary() => {
      'my_earned_count': 0,
      'my_recent': <dynamic>[],
      'academy_recent': <dynamic>[],
      // fallback keys antigos
      'recent_earned': <dynamic>[],
      'academy_feed': <dynamic>[],
    };

http.Response _dispatch(Uri uri) {
  final p = uri.path;
  if (p.endsWith('/users')) return _json([_user(), _user(id: 'u2', name: 'Bruno Dias')]);
  if (p.contains('/trophies/academy-earned')) return _json([]);
  if (p.endsWith('/trophies/me/home-summary')) return _json(_trophyHomeSummary());
  return _json([]);
}

Widget _screen({String currentUserId = 'u-test'}) => MaterialApp(
      home: ClassmatesGalleryScreen(
        academyId: 'ac1',
        currentUserId: currentUserId,
      ),
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
    setAuthForTesting();
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    clearAuthForTesting();
  });

  group('ClassmatesGalleryScreen — estrutura', () {
    testWidgets('renderiza sem crash com dados válidos', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(ClassmatesGalleryScreen), findsOneWidget);
    });

    testWidgets('não trava com lista vazia de usuários', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        final p = (inv.positionalArguments[0] as Uri).path;
        if (p.endsWith('/users')) return _json([]);
        if (p.contains('/trophies/academy-earned')) return _json([]);
        if (p.endsWith('/trophies/me/home-summary'))
          return _json(_trophyHomeSummary());
        return _json([]);
      });
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(ClassmatesGalleryScreen), findsOneWidget);
    });
  });

  group('ClassmatesGalleryScreen — conteúdo', () {
    testWidgets('exibe nome de colega na lista', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Ana'), findsWidgets);
    });

    testWidgets('exibe múltiplos colegas', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Bruno'), findsWidgets);
    });

    testWidgets('campo de busca está presente', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });
  });

  group('ClassmatesGalleryScreen — erro de rede', () {
    testWidgets('exibe estado de erro quando API falha', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                '{"detail": "Servidor indisponível"}',
                503,
                headers: {'content-type': 'application/json'},
              ));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
