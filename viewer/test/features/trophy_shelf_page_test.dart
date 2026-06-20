import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/features/trophy_shelf/presentation/trophy_shelf_page.dart';
import 'package:viewer/models/trophy.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

TrophyWithEarned _trophy({
  String id = 't1',
  String name = 'Chave de Braço',
  String? earnedTier = 'gold',
  bool unlocked = true,
  bool isManualAward = false,
  String? awardNote,
}) =>
    TrophyWithEarned(
      trophyId: id,
      techniqueId: 'tech1',
      name: name,
      startDate: '2026-01-01',
      endDate: '2026-12-31',
      targetCount: 5,
      unlocked: unlocked,
      earnedTier: earnedTier,
      isManualAward: isManualAward,
      awardNote: awardNote,
    );

Widget _page({List<TrophyWithEarned>? trophies}) => MaterialApp(
      home: TrophyShelfPage(
        userId: 'u-test',
        userName: 'Aluno Teste',
        trophies: trophies,
      ),
    );

// _pulse.repeat() e _shimmer.repeat() são animações infinitas.
// pumpAndSettle() nunca termina — usar pumps manuais.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 200));
}

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
    setAuthForTesting(user: stubStudent(id: 'u-test'));
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('TrophyShelfPage — estrutura', () {
    testWidgets('renderiza sem crash com lista vazia', (tester) async {
      await tester.pumpWidget(_page(trophies: []));
      await _settle(tester);

      expect(find.byType(TrophyShelfPage), findsOneWidget);
    });

    testWidgets('exibe mensagem quando não há troféus', (tester) async {
      await tester.pumpWidget(_page(trophies: []));
      await _settle(tester);

      expect(find.textContaining('Nenhum troféu'), findsWidgets);
    });

    testWidgets('não exibe CircularProgressIndicator quando trophies passado',
        (tester) async {
      await tester.pumpWidget(_page(trophies: []));
      await _settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('exibe título ESTANTE DE TROFÉUS no AppBar', (tester) async {
      await tester.pumpWidget(_page(trophies: []));
      await _settle(tester);

      expect(find.textContaining('TROFÉUS'), findsWidgets);
    });
  });

  group('TrophyShelfPage — conteúdo', () {
    testWidgets('exibe nome do troféu no card', (tester) async {
      await tester.pumpWidget(
          _page(trophies: [_trophy(name: 'Chave de Braço')]));
      await _settle(tester);

      expect(find.textContaining('Chave'), findsWidgets);
    });

    testWidgets('exibe badge OURO para troféu gold', (tester) async {
      await tester
          .pumpWidget(_page(trophies: [_trophy(earnedTier: 'gold')]));
      await _settle(tester);

      expect(find.textContaining('OURO'), findsWidgets);
    });

    testWidgets('exibe badge ESPECIAL para troféu manual', (tester) async {
      await tester.pumpWidget(_page(trophies: [
        _trophy(isManualAward: true, earnedTier: 'gold'),
      ]));
      await _settle(tester);

      expect(find.textContaining('ESPECIAL'), findsWidgets);
    });
  });

  group('TrophyShelfPage — via API', () {
    testWidgets('carrega via API quando trophies não passado', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('[]', 200,
              headers: {'content-type': 'application/json'}));
      ApiService().setHttpClientForTesting(client);

      // sem trophies → dispara _load() → 2 chamadas paralelas
      await tester.pumpWidget(_page());
      await _settle(tester);

      expect(find.byType(TrophyShelfPage), findsOneWidget);
    });
  });
}
