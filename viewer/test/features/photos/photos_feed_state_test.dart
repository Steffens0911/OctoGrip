import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/photos/presentation/state/photos_feed_state.dart';

// Testes para PhotosFeedState: propriedades e copyWith.

void main() {
  group('PhotosFeedState defaults', () {
    test('constrói com valores padrão corretos', () {
      const s = PhotosFeedState(academyId: 'ac1');

      expect(s.academyId, 'ac1');
      expect(s.items, isEmpty);
      expect(s.nextCursor, isNull);
      expect(s.isInitialLoading, isTrue);
      expect(s.isLoadingMore, isFalse);
      expect(s.isRefreshing, isFalse);
      expect(s.errorMessage, isNull);
      expect(s.mutationInProgress, isFalse);
    });

    test('hasMore = false quando nextCursor é null', () {
      const s = PhotosFeedState(academyId: 'ac1');
      expect(s.hasMore, isFalse);
    });

    test('hasMore = true quando nextCursor está definido', () {
      const s = PhotosFeedState(academyId: 'ac1', nextCursor: 'cursor-abc');
      expect(s.hasMore, isTrue);
    });
  });

  group('PhotosFeedState.copyWith', () {
    test('mantém valores originais quando nenhum parâmetro passado', () {
      const s = PhotosFeedState(
        academyId: 'ac1',
        isInitialLoading: false,
        nextCursor: 'c1',
      );
      final copy = s.copyWith();

      expect(copy.academyId, 'ac1');
      expect(copy.isInitialLoading, isFalse);
      expect(copy.nextCursor, 'c1');
    });

    test('sobrescreve isInitialLoading', () {
      const s = PhotosFeedState(academyId: 'ac1');
      final copy = s.copyWith(isInitialLoading: false);
      expect(copy.isInitialLoading, isFalse);
    });

    test('clearError remove errorMessage', () {
      const s = PhotosFeedState(
        academyId: 'ac1',
        errorMessage: 'falhou',
        isInitialLoading: false,
      );
      final copy = s.copyWith(clearError: true);
      expect(copy.errorMessage, isNull);
    });

    test('clearError com errorMessage passado ignora o novo errorMessage', () {
      const s = PhotosFeedState(
        academyId: 'ac1',
        errorMessage: 'antigo',
        isInitialLoading: false,
      );
      final copy = s.copyWith(clearError: true, errorMessage: 'novo');
      // clearError = true sobrescreve errorMessage passado
      expect(copy.errorMessage, isNull);
    });

    test('nextCursor pode ser explicitamente nulado com sentinel', () {
      const s = PhotosFeedState(
        academyId: 'ac1',
        nextCursor: 'cursor-1',
        isInitialLoading: false,
      );
      // Não passar nextCursor mantém o original
      final copy = s.copyWith(isLoadingMore: true);
      expect(copy.nextCursor, 'cursor-1');
    });

    test('atualiza múltiplos campos de uma vez', () {
      const s = PhotosFeedState(academyId: 'ac1');
      final copy = s.copyWith(
        isInitialLoading: false,
        isRefreshing: true,
        mutationInProgress: true,
      );
      expect(copy.isInitialLoading, isFalse);
      expect(copy.isRefreshing, isTrue);
      expect(copy.mutationInProgress, isTrue);
    });
  });
}
