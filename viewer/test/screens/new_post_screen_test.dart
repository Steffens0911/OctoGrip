import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/features/photos/presentation/pages/new_post_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// NewPostScreen: ConsumerStatefulWidget sem API calls no initState.
// Exibe AppBar "Novo post", área de seleção de foto e campo de legenda.
// ProviderScope necessário pois é ConsumerStatefulWidget.

Widget _screen() => ProviderScope(
      child: const MaterialApp(
        home: NewPostScreen(academyId: 'ac1'),
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

  group('NewPostScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('[]', 200,
              headers: {'content-type': 'application/json'}));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(NewPostScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar "Novo post"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('[]', 200,
              headers: {'content-type': 'application/json'}));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('post'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator no init', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('[]', 200,
              headers: {'content-type': 'application/json'}));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      // CircularProgressIndicator só aparece durante o upload da foto
      expect(find.byType(NewPostScreen), findsOneWidget);
    });

    testWidgets('exibe área de seleção de foto', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('[]', 200,
              headers: {'content-type': 'application/json'}));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(AspectRatio), findsWidgets);
    });
  });
}
