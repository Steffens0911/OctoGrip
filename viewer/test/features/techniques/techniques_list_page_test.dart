import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/presentation/pages/techniques_list_page.dart';
import 'package:viewer/features/techniques/presentation/providers/technique_providers.dart';
import 'package:viewer/features/techniques/presentation/state/technique_list_notifier.dart';
import 'package:viewer/features/techniques/presentation/state/technique_list_state.dart';

import '../../helpers/pump_app.dart';

// Stub do TechniqueListNotifier para evitar chamadas de rede/Hive nos testes.
class _FakeNotifier extends TechniqueListNotifier {
  final TechniqueListState fixedState;
  _FakeNotifier(this.fixedState);

  @override
  TechniqueListState build(String academyId) => fixedState;

  @override
  Future<void> refresh() async {}
  @override
  void onSearchChanged(String raw) {}
  @override
  void clearSearch() {}
  @override
  void loadMore() {}
}

Widget _page({required TechniqueListState state}) {
  return ProviderScope(
    overrides: [
      techniqueListNotifierProvider.overrideWith(() => _FakeNotifier(state)),
    ],
    child: const MaterialApp(
      home: TechniquesListPage(academyId: 'ac1'),
    ),
  );
}

void main() {
  setUpAll(disableGoogleFontsFetch);

  group('TechniquesListPage', () {
    testWidgets('exibe indicador de loading no estado inicial', (tester) async {
      await tester.pumpWidget(_page(
        state: const TechniqueListState(academyId: 'ac1'),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('exibe lista vazia com mensagem', (tester) async {
      await tester.pumpWidget(_page(
        state: const TechniqueListState(
          academyId: 'ac1',
          isInitialLoading: false,
        ),
      ));
      await tester.pump();

      expect(find.textContaining('Nenhuma técnica'), findsOneWidget);
    });

    testWidgets('exibe mensagem de erro quando falha e sem lista', (tester) async {
      await tester.pumpWidget(_page(
        state: const TechniqueListState(
          academyId: 'ac1',
          isInitialLoading: false,
          errorMessage: 'Sem conexão com servidor',
        ),
      ));
      await tester.pump();

      expect(find.text('Sem conexão com servidor'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('exibe itens da lista quando estado tem técnicas', (tester) async {
      const t1 = TechniqueEntity(
        id: 't1',
        academyId: 'ac1',
        name: 'Triângulo',
        slug: 'triangulo',
      );
      const t2 = TechniqueEntity(
        id: 't2',
        academyId: 'ac1',
        name: 'Armlock',
        slug: 'armlock',
      );

      await tester.pumpWidget(_page(
        state: const TechniqueListState(
          academyId: 'ac1',
          isInitialLoading: false,
          allItems: [t1, t2],
          visibleCount: 20,
        ),
      ));
      await tester.pump();

      expect(find.text('Triângulo'), findsOneWidget);
      expect(find.text('Armlock'), findsOneWidget);
    });

    testWidgets('exibe campo de busca na tela', (tester) async {
      await tester.pumpWidget(_page(
        state: const TechniqueListState(
          academyId: 'ac1',
          isInitialLoading: false,
        ),
      ));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
