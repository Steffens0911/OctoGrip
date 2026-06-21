import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/app_theme.dart';

import '../helpers/pump_app.dart';

// Testes para AppThemeStyleExtension e helpers de BuildContext do AppTheme.

void main() {
  setUpAll(disableGoogleFontsFetch);

  group('AppThemeStyleExtension', () {
    test('isPremiumStyle = true quando não é game nem memo', () {
      const ext = AppThemeStyleExtension(isGameStyle: false);
      expect(ext.isPremiumStyle, isTrue);
      expect(ext.isGameStyle, isFalse);
      expect(ext.isMemoStyle, isFalse);
    });

    test('isPremiumStyle = false quando isGameStyle = true', () {
      const ext = AppThemeStyleExtension(isGameStyle: true);
      expect(ext.isPremiumStyle, isFalse);
    });

    test('isPremiumStyle = false quando isMemoStyle = true', () {
      const ext = AppThemeStyleExtension(isGameStyle: false, isMemoStyle: true);
      expect(ext.isPremiumStyle, isFalse);
    });

    test('copyWith substitui isGameStyle', () {
      const ext = AppThemeStyleExtension(isGameStyle: false);
      final copy = ext.copyWith(isGameStyle: true);
      expect(copy.isGameStyle, isTrue);
      expect(copy.isMemoStyle, isFalse);
    });

    test('copyWith substitui isMemoStyle', () {
      const ext = AppThemeStyleExtension(isGameStyle: false);
      final copy = ext.copyWith(isMemoStyle: true);
      expect(copy.isMemoStyle, isTrue);
    });

    test('lerp t<0.5 retorna this', () {
      const a = AppThemeStyleExtension(isGameStyle: false);
      const b = AppThemeStyleExtension(isGameStyle: true);
      final result = a.lerp(b, 0.3);
      expect(result.isGameStyle, isFalse);
    });

    test('lerp t>=0.5 retorna other', () {
      const a = AppThemeStyleExtension(isGameStyle: false);
      const b = AppThemeStyleExtension(isGameStyle: true);
      final result = a.lerp(b, 0.7);
      expect(result.isGameStyle, isTrue);
    });

    test('lerp com tipo diferente retorna this', () {
      const a = AppThemeStyleExtension(isGameStyle: true);
      final result = a.lerp(null, 0.9);
      expect(result.isGameStyle, isTrue);
    });
  });

  group('AppTheme helpers (widget context)', () {
    testWidgets('screenPadding retorna valor > 0 para tela padrão', (tester) async {
      double? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              captured = AppTheme.screenPadding(ctx);
              return const Placeholder();
            },
          ),
        ),
      );
      expect(captured, greaterThan(0));
    });

    testWidgets('isNarrow retorna bool para tela padrão (800px)', (tester) async {
      bool? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              captured = AppTheme.isNarrow(ctx);
              return const Placeholder();
            },
          ),
        ),
      );
      // Tela de teste = 800px >= breakpointTablet (600), então não é estreita
      expect(captured, isFalse);
    });

    testWidgets('backgroundOf retorna cor não-transparente', (tester) async {
      Color? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              captured = AppTheme.backgroundOf(ctx);
              return const Placeholder();
            },
          ),
        ),
      );
      expect(captured!.a, greaterThan(0));
    });

    testWidgets('surfaceOf retorna cor não-transparente', (tester) async {
      Color? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              captured = AppTheme.surfaceOf(ctx);
              return const Placeholder();
            },
          ),
        ),
      );
      expect(captured!.a, greaterThan(0));
    });

    testWidgets('textPrimaryOf retorna cor não-transparente', (tester) async {
      Color? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              captured = AppTheme.textPrimaryOf(ctx);
              return const Placeholder();
            },
          ),
        ),
      );
      expect(captured!.a, greaterThan(0));
    });

    testWidgets('textSecondaryOf retorna cor não-transparente', (tester) async {
      Color? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              captured = AppTheme.textSecondaryOf(ctx);
              return const Placeholder();
            },
          ),
        ),
      );
      expect(captured!.a, greaterThan(0));
    });

    testWidgets('textMutedOf retorna cor não-transparente', (tester) async {
      Color? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              captured = AppTheme.textMutedOf(ctx);
              return const Placeholder();
            },
          ),
        ),
      );
      expect(captured!.a, greaterThan(0));
    });

    testWidgets('borderOf retorna cor não-transparente', (tester) async {
      Color? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              captured = AppTheme.borderOf(ctx);
              return const Placeholder();
            },
          ),
        ),
      );
      expect(captured!.a, greaterThan(0));
    });
  });

  group('AppTheme constantes', () {
    test('primary é âmbar/dourado não-transparente', () {
      expect(AppTheme.primary.a, 1.0);
    });

    test('breakpoints têm valores esperados', () {
      expect(AppTheme.breakpointTablet, 600);
      expect(AppTheme.breakpointDesktop, 900);
      expect(AppTheme.maxContentWidth, 720);
    });
  });

  group('AppTheme ThemeData builders', () {
    testWidgets('light retorna ThemeData com brightness=light', (tester) async {
      ThemeData? theme;
      await tester.pumpWidget(Builder(builder: (ctx) {
        theme = AppTheme.light;
        return const SizedBox.shrink();
      }));
      expect(theme!.brightness, Brightness.light);
      expect(theme!.useMaterial3, isTrue);
    });

    testWidgets('dark retorna ThemeData com brightness=dark', (tester) async {
      ThemeData? theme;
      await tester.pumpWidget(Builder(builder: (ctx) {
        theme = AppTheme.dark;
        return const SizedBox.shrink();
      }));
      expect(theme!.brightness, Brightness.dark);
      expect(theme!.useMaterial3, isTrue);
    });

    testWidgets('premiumLight retorna ThemeData com brightness=light',
        (tester) async {
      ThemeData? theme;
      await tester.pumpWidget(Builder(builder: (ctx) {
        theme = AppTheme.premiumLight;
        return const SizedBox.shrink();
      }));
      expect(theme!.brightness, Brightness.light);
    });

    testWidgets('premiumDark retorna ThemeData com brightness=dark',
        (tester) async {
      ThemeData? theme;
      await tester.pumpWidget(Builder(builder: (ctx) {
        theme = AppTheme.premiumDark;
        return const SizedBox.shrink();
      }));
      expect(theme!.brightness, Brightness.dark);
    });

    testWidgets('memoLight retorna ThemeData com brightness=light',
        (tester) async {
      ThemeData? theme;
      await tester.pumpWidget(Builder(builder: (ctx) {
        theme = AppTheme.memoLight;
        return const SizedBox.shrink();
      }));
      expect(theme!.brightness, Brightness.light);
    });

    testWidgets('memoDark retorna ThemeData com brightness=dark',
        (tester) async {
      ThemeData? theme;
      await tester.pumpWidget(Builder(builder: (ctx) {
        theme = AppTheme.memoDark;
        return const SizedBox.shrink();
      }));
      expect(theme!.brightness, Brightness.dark);
    });

    testWidgets('memoLightSans retorna ThemeData com brightness=light',
        (tester) async {
      ThemeData? theme;
      await tester.pumpWidget(Builder(builder: (ctx) {
        theme = AppTheme.memoLightSans;
        return const SizedBox.shrink();
      }));
      expect(theme!.brightness, Brightness.light);
    });

    testWidgets('memoDarkSans retorna ThemeData com brightness=dark',
        (tester) async {
      ThemeData? theme;
      await tester.pumpWidget(Builder(builder: (ctx) {
        theme = AppTheme.memoDarkSans;
        return const SizedBox.shrink();
      }));
      expect(theme!.brightness, Brightness.dark);
    });
  });
}
