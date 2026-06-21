import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';
import 'package:viewer/features/trophies/presentation/pages/trophies_list_page.dart';
import 'package:viewer/features/trophies/presentation/providers/trophy_providers.dart';
import 'package:viewer/features/trophies/presentation/state/trophy_list_notifier.dart';
import 'package:viewer/features/trophies/presentation/state/trophy_list_state.dart';

import '../../helpers/pump_app.dart';

class _FakeNotifier extends TrophyListNotifier {
  final TrophyListState fixedState;
  _FakeNotifier(this.fixedState);

  @override
  TrophyListState build(String academyId) => fixedState;

  @override
  Future<void> refresh() async {}
  @override
  void onSearchChanged(String raw) {}
  @override
  void clearSearch() {}
  @override
  void loadMore() {}
}

Widget _page({required TrophyListState state}) {
  return ProviderScope(
    overrides: [
      trophyListNotifierProvider.overrideWith(() => _FakeNotifier(state)),
    ],
    child: const MaterialApp(
      home: TrophiesListPage(academyId: 'ac1', academyName: 'Octogrip'),
    ),
  );
}

void main() {
  setUpAll(disableGoogleFontsFetch);

  group('TrophiesListPage', () {
    testWidgets('exibe indicador de loading no estado inicial', (tester) async {
      await tester.pumpWidget(_page(
        state: const TrophyListState(academyId: 'ac1'),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('exibe mensagem de lista vazia', (tester) async {
      await tester.pumpWidget(_page(
        state: const TrophyListState(
          academyId: 'ac1',
          isInitialLoading: false,
        ),
      ));
      await tester.pump();

      expect(find.textContaining('Nenhum troféu'), findsOneWidget);
    });

    testWidgets('exibe mensagem de erro quando falha e sem lista', (tester) async {
      await tester.pumpWidget(_page(
        state: const TrophyListState(
          academyId: 'ac1',
          isInitialLoading: false,
          errorMessage: 'Falha ao carregar troféus',
        ),
      ));
      await tester.pump();

      expect(find.text('Falha ao carregar troféus'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('exibe troféus quando estado tem itens', (tester) async {
      const t1 = TrophyEntity(
        id: 'tr1',
        academyId: 'ac1',
        techniqueId: 'tech1',
        name: 'Armlock 5x',
        startDateIso: '2026-01-01',
        endDateIso: '2026-12-31',
        targetCount: 5,
        awardKind: 'trophy',
      );

      await tester.pumpWidget(_page(
        state: const TrophyListState(
          academyId: 'ac1',
          isInitialLoading: false,
          allItems: [t1],
          visibleCount: 20,
        ),
      ));
      await tester.pump();

      expect(find.text('Armlock 5x'), findsOneWidget);
    });

    testWidgets('exibe campo de busca', (tester) async {
      await tester.pumpWidget(_page(
        state: const TrophyListState(
          academyId: 'ac1',
          isInitialLoading: false,
        ),
      ));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
