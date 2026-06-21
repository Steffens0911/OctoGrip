import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/services/theme_service.dart';

// Testes unitários para ThemeService: persistência de tema, estilo e fonte.

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeService.load', () {
    test('retorna dark por padrão quando não há preferência salva', () async {
      final mode = await ThemeService.load();
      expect(mode, ThemeMode.dark);
    });

    test('retorna light após salvar light', () async {
      await ThemeService.save(ThemeMode.light);
      final mode = await ThemeService.load();
      expect(mode, ThemeMode.light);
    });

    test('retorna system após salvar system', () async {
      await ThemeService.save(ThemeMode.system);
      final mode = await ThemeService.load();
      expect(mode, ThemeMode.system);
    });
  });

  group('ThemeService.next', () {
    test('light → dark', () {
      expect(ThemeService.next(ThemeMode.light), ThemeMode.dark);
    });

    test('dark → light', () {
      expect(ThemeService.next(ThemeMode.dark), ThemeMode.light);
    });

    test('system dark → light', () {
      expect(ThemeService.next(ThemeMode.system, Brightness.dark), ThemeMode.light);
    });

    test('system light → dark', () {
      expect(ThemeService.next(ThemeMode.system, Brightness.light), ThemeMode.dark);
    });
  });

  group('ThemeService.label', () {
    test('retorna labels corretos', () {
      expect(ThemeService.label(ThemeMode.light), 'Claro');
      expect(ThemeService.label(ThemeMode.dark), 'Escuro');
      expect(ThemeService.label(ThemeMode.system), 'Sistema');
    });
  });

  group('ThemeService.loadStyle', () {
    test('retorna game por padrão', () async {
      final style = await ThemeService.loadStyle();
      expect(style, ThemeStyle.game);
    });

    test('retorna premium após salvar premium', () async {
      await ThemeService.saveStyle(ThemeStyle.premium);
      final style = await ThemeService.loadStyle();
      expect(style, ThemeStyle.premium);
    });

    test('retorna memo após salvar memo', () async {
      await ThemeService.saveStyle(ThemeStyle.memo);
      final style = await ThemeService.loadStyle();
      expect(style, ThemeStyle.memo);
    });
  });

  group('ThemeService.nextStyle', () {
    test('game → premium → memo → game', () {
      expect(ThemeService.nextStyle(ThemeStyle.game), ThemeStyle.premium);
      expect(ThemeService.nextStyle(ThemeStyle.premium), ThemeStyle.memo);
      expect(ThemeService.nextStyle(ThemeStyle.memo), ThemeStyle.game);
    });
  });

  group('ThemeService.labelStyle', () {
    test('retorna labels corretos', () {
      expect(ThemeService.labelStyle(ThemeStyle.game), 'Jogo');
      expect(ThemeService.labelStyle(ThemeStyle.premium), 'Premium');
      expect(ThemeService.labelStyle(ThemeStyle.memo), 'Memo');
    });
  });

  group('ThemeService.clampTextScale', () {
    test('clamp para mínimo', () {
      expect(ThemeService.clampTextScale(0.5), TextScalePrefs.min);
    });

    test('clamp para máximo', () {
      expect(ThemeService.clampTextScale(2.0), TextScalePrefs.max);
    });

    test('valor válido inalterado', () {
      expect(ThemeService.clampTextScale(1.0), 1.0);
    });
  });

  group('ThemeService.loadTextScale', () {
    test('retorna default quando não há valor salvo', () async {
      final scale = await ThemeService.loadTextScale();
      expect(scale, TextScalePrefs.defaultScale);
    });

    test('retorna valor salvo com clamp aplicado', () async {
      await ThemeService.saveTextScale(1.2);
      final scale = await ThemeService.loadTextScale();
      expect(scale, closeTo(1.2, 0.001));
    });
  });

  group('ThemeService.loadUseGameFont', () {
    test('retorna true por padrão', () async {
      final useGame = await ThemeService.loadUseGameFont();
      expect(useGame, isTrue);
    });

    test('retorna false após salvar sans', () async {
      await ThemeService.saveUseGameFont(false);
      final useGame = await ThemeService.loadUseGameFont();
      expect(useGame, isFalse);
    });
  });
}
