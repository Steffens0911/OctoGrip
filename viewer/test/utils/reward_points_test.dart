import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/constants/reward_points.dart';

// Testes para as funções utilitárias de pontos de recompensa.

void main() {
  group('isValidRewardPoints', () {
    test('retorna true para valor dentro do intervalo', () {
      expect(isValidRewardPoints(10), isTrue);
      expect(isValidRewardPoints(25), isTrue);
      expect(isValidRewardPoints(50), isTrue);
    });

    test('retorna false para valor abaixo do mínimo', () {
      expect(isValidRewardPoints(9), isFalse);
      expect(isValidRewardPoints(0), isFalse);
    });

    test('retorna false para valor acima do máximo', () {
      expect(isValidRewardPoints(51), isFalse);
      expect(isValidRewardPoints(100), isFalse);
    });
  });

  group('clampRewardPoints', () {
    test('retorna valor inalterado quando dentro do intervalo', () {
      expect(clampRewardPoints(25), 25);
      expect(clampRewardPoints(minRewardPoints), minRewardPoints);
      expect(clampRewardPoints(maxRewardPoints), maxRewardPoints);
    });

    test('retorna mínimo quando valor abaixo', () {
      expect(clampRewardPoints(5), minRewardPoints);
      expect(clampRewardPoints(-10), minRewardPoints);
    });

    test('retorna máximo quando valor acima', () {
      expect(clampRewardPoints(100), maxRewardPoints);
      expect(clampRewardPoints(51), maxRewardPoints);
    });
  });
}
