import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/design/app_tokens.dart';

// Testes para AppSpacing e AppRadius.

void main() {
  group('AppSpacing', () {
    test('constantes de espaçamento são corretas', () {
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.s, 8.0);
      expect(AppSpacing.m, 16.0);
      expect(AppSpacing.l, 24.0);
      expect(AppSpacing.xl, 32.0);
      expect(AppSpacing.xxl, 40.0);
    });

    test('paddingM tem todos os lados = 16', () {
      expect(AppSpacing.paddingM, const EdgeInsets.all(16));
    });

    test('verticalM tem altura = 16', () {
      expect((AppSpacing.verticalM).height, 16.0);
    });
  });

  group('AppRadius', () {
    test('constantes de radius são corretas', () {
      expect(AppRadius.card, 16.0);
      expect(AppRadius.button, 12.0);
      expect(AppRadius.input, 12.0);
      expect(AppRadius.tile, 12.0);
      expect(AppRadius.chip, 8.0);
    });

    test('cardRadius retorna BorderRadius.circular(16)', () {
      expect(AppRadius.cardRadius, BorderRadius.circular(16));
    });

    test('buttonRadius retorna BorderRadius.circular(12)', () {
      expect(AppRadius.buttonRadius, BorderRadius.circular(12));
    });

    test('inputRadius retorna BorderRadius.circular(12)', () {
      expect(AppRadius.inputRadius, BorderRadius.circular(12));
    });

    test('tileRadius retorna BorderRadius.circular(12)', () {
      expect(AppRadius.tileRadius, BorderRadius.circular(12));
    });

    test('chipRadius retorna BorderRadius.circular(8)', () {
      expect(AppRadius.chipRadius, BorderRadius.circular(8));
    });
  });
}
