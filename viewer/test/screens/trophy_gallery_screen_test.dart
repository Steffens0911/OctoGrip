import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/features/trophy_shelf/presentation/trophy_shelf_page.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _manualEmpty() => {
      'championship_awards': <dynamic>[],
      'custom_awards': <dynamic>[],
    };

Map<String, dynamic> _trophy({
  String id = 'tr1',
  String name = 'Armlock 5x',
  String? earnedTier,
}) =>
    {
      'trophy_id': id,
      'technique_id': 'tech1',
      'name': name,
      'technique_name': 'Armlock',
      'academy_id': 'ac1',
      'start_date': '2026-01-01',
      'end_date': '2026-12-31',
      'target_count': 5,
      'award_kind': 'trophy',
      'earned_tier': earnedTier,
      'gold_count': earnedTier == 'gold' ? 1 : 0,
      'silver_count': earnedTier == 'silver' ? 1 : 0,
      'bronze_count': earnedTier == 'bronze' ? 1 : 0,
    };

Widget _screen({String userId = 'u-test'}) => MaterialApp(
      home: ChangeNotifierProvider<AuthService>.value(
        value: AuthService(),
        child: TrophyShelfPage(userId: userId, userName: 'Fulano'),
      ),
    );

http.Response _dispatch(Uri uri) {
  final p = uri.path;
  if (p.contains('/manual-trophies/awards/user/')) return _json(_manualEmpty());
  if (p.contains('/trophies/user/')) return _json([_trophy()]);
  return _json([]);
}

// TrophyShelfPage usa AnimationController.repeat() — pumpAndSettle trava.
// Usamos pumps sequenciais para deixar a API mock resolver.
Future<void> _pumpShelf(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

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

  group('TrophyShelfPage — conteúdo', () {
    testWidgets('renderiza nome do troféu após carregar', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async =>
              _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _pumpShelf(tester);

      expect(find.textContaining('Armlock'), findsWidgets);
    });

    testWidgets('galeria vazia não exibe indicador de carregamento', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        final p = (inv.positionalArguments[0] as Uri).path;
        if (p.contains('/trophies/user/')) return _json([]);
        if (p.contains('/manual-trophies/')) return _json(_manualEmpty());
        return _json([]);
      });
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _pumpShelf(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('troféu conquistado (gold) é exibido sem indicador de carregamento', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        final p = (inv.positionalArguments[0] as Uri).path;
        if (p.contains('/trophies/user/')) {
          return _json([_trophy(earnedTier: 'gold')]);
        }
        if (p.contains('/manual-trophies/')) return _json(_manualEmpty());
        return _json([]);
      });
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _pumpShelf(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('TrophyShelfPage — galeria privada', () {
    testWidgets('exibe mensagem de privacidade quando recebe 403', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async {
        final p = (inv.positionalArguments[0] as Uri).path;
        if (p.contains('/manual-trophies/')) return _json(_manualEmpty());
        return _json({'detail': 'Forbidden'}, 403);
      });
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen(userId: 'outro-user'));
      await _pumpShelf(tester);

      expect(find.text('Esta galeria está privada.'), findsOneWidget);
    });
  });

  group('TrophyShelfPage — busca', () {
    testWidgets('campo de busca está presente após carregar', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((inv) async =>
              _dispatch(inv.positionalArguments[0] as Uri));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await _pumpShelf(tester);

      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });
  });
}
