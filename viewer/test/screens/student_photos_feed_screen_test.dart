import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/features/photos/presentation/pages/student_photos_feed_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// StudentPhotosFeedPage: Scaffold que contém StudentPhotosFeedScreen (ConsumerWidget).
// Riverpod provider chama GET /academies/{id}/photos ao iniciar.
// _StudentProfileHeader llama GET /users/{id}/trophies + points (silenciado em catch).
// Mock tudo para retornar respostas adequadas ou vazio.

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

// Dispatch: fotos → page vazia; resto → objeto/lista vazia para silenciar erros.
http.Response _dispatch(Uri uri) {
  final path = uri.path;
  if (path.contains('/photos')) {
    return _json({'items': [], 'next_cursor': null});
  }
  return _json({});
}

Widget _screen() => ProviderScope(
      child: const MaterialApp(
        home: StudentPhotosFeedPage(
          academyId: 'ac1',
          studentId: 'u1',
          studentName: 'João Silva',
        ),
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
    setAuthForTesting();
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('StudentPhotosFeedPage — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(StudentPhotosFeedPage), findsOneWidget);
    });

    testWidgets('exibe AppBar "Fotos"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Fotos'), findsWidgets);
    });

    testWidgets('exibe nome do aluno no subtítulo', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async => _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('João'), findsWidgets);
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
}
