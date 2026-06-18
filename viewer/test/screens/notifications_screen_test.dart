import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/screens/notifications_screen.dart';
import 'package:viewer/screens/student/marketplace_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _notif({
  String id = 'n1',
  String type = 'academy_push',
  String title = 'Novo produto na loja',
  String body = 'Kimono GI',
  bool read = false,
}) =>
    {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'read': read,
      'data': null,
      'created_at': '2026-06-17T10:00:00Z',
    };

MockHttpClient _buildClient({List<Map<String, dynamic>>? notifs}) {
  final client = MockHttpClient();
  final list = notifs ?? [_notif()];
  when(() => client.get(any(), headers: any(named: 'headers')))
      .thenAnswer((inv) async {
    final uri = inv.positionalArguments[0] as Uri;
    if (uri.path.contains('/notifications')) return _json(list);
    // MarketplaceScreen carregada após navegação
    if (uri.path.contains('/me/marketplace_items')) return _json([]);
    return _json([]);
  });
  // _markRead chama POST /notifications/{id}/read
  when(() => client.post(any(), headers: any(named: 'headers')))
      .thenAnswer((_) async => http.Response('', 204));
  return client;
}

Widget _screen() => const MaterialApp(home: NotificationsScreen());

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

  // ---- Mapeamento de categoria ----

  group('NotificationsScreen — academy_push na lista', () {
    testWidgets('exibe título da notificação após carregar', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.text('Novo produto na loja'), findsOneWidget);
    });

    testWidgets('academy_push exibe emoji 🛍️', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.text('🛍️'), findsOneWidget);
    });

    testWidgets('academy_push é incluído no filtro "Avisos"', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      // Seleciona o chip "Avisos"
      await tester.tap(find.text('Avisos'));
      await tester.pumpAndSettle();

      expect(find.text('Novo produto na loja'), findsOneWidget);
    });

    testWidgets('academy_push NÃO aparece no filtro "Missões"', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Missões'));
      await tester.pumpAndSettle();

      expect(find.text('Novo produto na loja'), findsNothing);
    });
  });

  // ---- Navegação ao tocar ----

  group('NotificationsScreen — navegação academy_push', () {
    testWidgets('tap em academy_push abre MarketplaceScreen', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient());

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Novo produto na loja'));
      await tester.pumpAndSettle();

      expect(find.byType(MarketplaceScreen), findsOneWidget);
    });

    testWidgets('tap em trophy_earned NÃO abre MarketplaceScreen', (tester) async {
      ApiService().setHttpClientForTesting(_buildClient(notifs: [
        _notif(
          type: 'trophy_earned',
          title: 'Troféu conquistado!',
          body: 'Armlock 5x',
        ),
      ]));

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Troféu conquistado!'));
      await tester.pumpAndSettle();

      expect(find.byType(MarketplaceScreen), findsNothing);
    });
  });
}
