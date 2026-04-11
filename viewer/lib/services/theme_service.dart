import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyThemeMode = 'theme_mode';
const _keyThemeStyle = 'theme_style';
const _keyFontStyle = 'font_style';
const _keyTextScale = 'text_scale';

/// Contrato da escala de texto global (MaterialApp + botões na AppBar).
/// Passo por toque na UI; valores persistidos fora do intervalo são corrigidos ao carregar.
abstract final class TextScalePrefs {
  static const double min = 0.85;
  static const double max = 1.30;
  static const double defaultScale = 1.0;
  static const double step = 0.05;
}

/// Estilo visual do app: jogo (marrom/âmbar), premium (lavanda/claro) ou memo (Memo UI Kit).
enum ThemeStyle {
  game,
  premium,
  memo,
}

/// Serviço para persistir e restaurar preferência de tema (light/dark/system), estilo (game/premium),
/// família de fonte (jogo/sans) e escala de texto global ([TextScalePrefs] + [loadTextScale]/[saveTextScale]).
class ThemeService {
  static Future<ThemeMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyThemeMode);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        // Sem preferência salva: tema escuro (login e novos usuários).
        return ThemeMode.dark;
    }
  }

  static Future<void> save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_keyThemeMode, value);
  }

  /// Um toque: alterna entre claro e escuro (toggle binário).
  static ThemeMode next(ThemeMode current, [Brightness? resolvedBrightness]) {
    if (current == ThemeMode.system && resolvedBrightness != null) {
      return resolvedBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    }
    return switch (current) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.system => resolvedBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    };
  }

  static String label(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'Claro',
      ThemeMode.dark => 'Escuro',
      ThemeMode.system => 'Sistema',
    };
  }

  static Future<ThemeStyle> loadStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyThemeStyle);
    return switch (value) {
      'premium' => ThemeStyle.premium,
      'memo' => ThemeStyle.memo,
      _ => ThemeStyle.game,
    };
  }

  static Future<void> saveStyle(ThemeStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (style) {
      ThemeStyle.game => 'game',
      ThemeStyle.premium => 'premium',
      ThemeStyle.memo => 'memo',
    };
    await prefs.setString(_keyThemeStyle, value);
  }

  /// Alterna entre estilos: game → premium → memo → game.
  static ThemeStyle nextStyle(ThemeStyle current) {
    return switch (current) {
      ThemeStyle.game => ThemeStyle.premium,
      ThemeStyle.premium => ThemeStyle.memo,
      ThemeStyle.memo => ThemeStyle.game,
    };
  }

  static String labelStyle(ThemeStyle style) {
    return switch (style) {
      ThemeStyle.game => 'Jogo',
      ThemeStyle.premium => 'Premium',
      ThemeStyle.memo => 'Memo',
    };
  }

  static Future<bool> loadUseGameFont() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyFontStyle);
    return value != 'sans';
  }

  static Future<void> saveUseGameFont(bool useGameFont) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontStyle, useGameFont ? 'game' : 'sans');
  }

  /// Fator linear de escala de texto (`TextScaler.linear`); aplica-se a login e shell.
  static double clampTextScale(double value) =>
      value.clamp(TextScalePrefs.min, TextScalePrefs.max);

  static Future<double> loadTextScale() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getDouble(_keyTextScale);
    if (raw == null) return TextScalePrefs.defaultScale;
    return clampTextScale(raw);
  }

  static Future<void> saveTextScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTextScale, clampTextScale(scale));
  }
}
