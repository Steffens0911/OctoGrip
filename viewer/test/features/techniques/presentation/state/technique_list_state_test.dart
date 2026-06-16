import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/presentation/state/technique_list_state.dart';

TechniqueEntity makeEntity({String id = 'id1', String name = 'Armlock'}) =>
    TechniqueEntity(id: id, academyId: 'ac1', name: name, slug: name.toLowerCase().replaceAll(' ', '-'));

void main() {
  group('TechniqueListState.filtered', () {
    test('retorna todos os itens quando searchQuery vazio', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        allItems: [makeEntity(), makeEntity(id: 'id2', name: 'Triângulo')],
      );
      expect(state.filtered, hasLength(2));
    });

    test('filtra por nome (case insensitive)', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        allItems: [makeEntity(name: 'Armlock'), makeEntity(id: 'id2', name: 'Triângulo')],
        searchQuery: 'arm',
      );
      expect(state.filtered, hasLength(1));
      expect(state.filtered.first.name, 'Armlock');
    });

    test('query em maiúsculas bate com nome em minúsculas', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        allItems: [makeEntity(name: 'armlock')],
        searchQuery: 'ARMLOCK',
      );
      expect(state.filtered, hasLength(1));
    });

    test('retorna lista vazia quando nenhum item bate', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        allItems: [makeEntity(name: 'Armlock')],
        searchQuery: 'xyz',
      );
      expect(state.filtered, isEmpty);
    });

    test('trim no searchQuery é aplicado antes do filtro', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        allItems: [makeEntity(name: 'Armlock')],
        searchQuery: '  arm  ',
      );
      expect(state.filtered, hasLength(1));
    });
  });

  group('TechniqueListState.visible / hasMore', () {
    final items = List.generate(
      25,
      (i) => makeEntity(id: 'id$i', name: 'Técnica ${i.toString().padLeft(2, '0')}'),
    );

    test('visible limita ao visibleCount', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        allItems: items,
        pageSize: 20,
        visibleCount: 20,
      );
      expect(state.visible, hasLength(20));
      expect(state.hasMore, isTrue);
    });

    test('visible retorna todos quando visibleCount >= total', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        allItems: items,
        visibleCount: 50,
      );
      expect(state.visible, hasLength(25));
      expect(state.hasMore, isFalse);
    });

    test('hasMore false com lista vazia', () {
      final state = TechniqueListState(academyId: 'ac1');
      expect(state.hasMore, isFalse);
    });
  });

  group('TechniqueListState.isEmpty', () {
    test('true quando lista vazia e não carregando', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        allItems: const [],
        isInitialLoading: false,
      );
      expect(state.isEmpty, isTrue);
    });

    test('false durante isInitialLoading mesmo com lista vazia', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        allItems: const [],
        isInitialLoading: true,
      );
      expect(state.isEmpty, isFalse);
    });

    test('false quando há itens', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        allItems: [makeEntity()],
        isInitialLoading: false,
      );
      expect(state.isEmpty, isFalse);
    });

    test('false quando searchQuery não retorna resultado mas está carregando', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        allItems: [makeEntity()],
        searchQuery: 'xyz_nao_existe',
        isInitialLoading: false,
      );
      // filtered está vazio, isInitialLoading false → isEmpty true (search sem resultado)
      expect(state.isEmpty, isTrue);
    });
  });

  group('TechniqueListState.copyWith', () {
    test('clearError remove errorMessage e showingStaleCache', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        errorMessage: 'Erro de rede',
        showingStaleCache: true,
      );
      final next = state.copyWith(clearError: true);
      expect(next.errorMessage, isNull);
      expect(next.showingStaleCache, isFalse);
    });

    test('clearError=false preserva errorMessage existente', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        errorMessage: 'Erro',
      );
      final next = state.copyWith(isRefreshing: true);
      expect(next.errorMessage, 'Erro');
    });

    test('preserva campos não alterados', () {
      final state = TechniqueListState(
        academyId: 'ac1',
        allItems: [makeEntity()],
        searchQuery: 'arm',
        isInitialLoading: false,
      );
      final next = state.copyWith(isRefreshing: true);
      expect(next.allItems, hasLength(1));
      expect(next.searchQuery, 'arm');
      expect(next.isInitialLoading, isFalse);
      expect(next.isRefreshing, isTrue);
    });

    test('academyId é invariável no copyWith', () {
      final state = TechniqueListState(academyId: 'ac42');
      final next = state.copyWith(isRefreshing: true);
      expect(next.academyId, 'ac42');
    });
  });
}
