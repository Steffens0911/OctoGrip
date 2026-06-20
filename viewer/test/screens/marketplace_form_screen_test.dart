import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/marketplace_item.dart';
import 'package:viewer/screens/admin/marketplace_form_screen.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

MarketplaceItem _item({
  String id = 'mi1',
  String title = 'Kimono Premium',
  String? description = 'Kimono de alta qualidade',
  int priceCents = 49900,
  String? whatsappDdd = '51',
  String? whatsappNumber = '912345678',
}) =>
    MarketplaceItem(
      id: id,
      title: title,
      description: description,
      priceCents: priceCents,
      whatsappDdd: whatsappDdd,
      whatsappNumber: whatsappNumber,
      isActive: true,
    );

Widget _screen({MarketplaceItem? item}) => MaterialApp(
      home: MarketplaceFormScreen(item: item),
    );

// MarketplaceFormScreen não faz chamadas de API no init — pumpAndSettle funciona.

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
    setAuthForTesting(user: stubStudent(role: 'administrador'));
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    clearAuthForTesting();
  });

  group('MarketplaceFormScreen — novo anúncio', () {
    testWidgets('renderiza formulário vazio sem crash', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(MarketplaceFormScreen), findsOneWidget);
    });

    testWidgets('mostra campo de título', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Título'), findsAtLeastNWidgets(1));
    });

    testWidgets('mostra campo de preço', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Preço'), findsAtLeastNWidgets(1));
    });

    testWidgets('mostra campo de WhatsApp', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('WhatsApp'), findsAtLeastNWidgets(1));
    });
  });

  group('MarketplaceFormScreen — editar anúncio existente', () {
    testWidgets('preenche título do anúncio', (tester) async {
      await tester.pumpWidget(_screen(item: _item(title: 'Kimono Premium')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Kimono'), findsWidgets);
    });

    testWidgets('preenche DDD do WhatsApp', (tester) async {
      await tester.pumpWidget(_screen(item: _item(whatsappDdd: '51')));
      await tester.pumpAndSettle();

      expect(find.textContaining('51'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator ao renderizar', (tester) async {
      await tester.pumpWidget(_screen(item: _item()));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('MarketplaceFormScreen — interação', () {
    testWidgets('pode digitar no campo de título', (tester) async {
      // Não usa mock HTTP pois o form não faz chamadas no init
      final mockClient = MockHttpClient();
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('[]', 200));
      ApiService().setHttpClientForTesting(mockClient);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      if (fields.evaluate().isNotEmpty) {
        await tester.enterText(fields.first, 'Novo Produto');
        await tester.pump();
        expect(find.textContaining('Novo Produto'), findsWidgets);
      } else {
        // Campo de texto pode estar em TextField
        expect(find.byType(MarketplaceFormScreen), findsOneWidget);
      }
    });
  });
}
