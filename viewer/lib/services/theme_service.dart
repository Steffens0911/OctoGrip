import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyThemeMode = 'theme_mode';
const _keyThemeStyle = 'theme_style';

/// Estilo visual do app: jogo (marrom/âmbar), premium (lavanda/claro) ou memo (Memo UI Kit).
enum ThemeStyle {
  game,
  premium,
  memo,
}

/// Serviço para persistir e restaurar preferência de tema (light/dark/system) e estilo (game/premium).
class ThemeService {
  static Future<ThemeMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyThemeMode);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
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

  /// Ciclo: light ↔ dark. Se [resolvedBrightness] for passado e current for system,
  /// retorna o tema oposto ao que está sendo exibido (um clique alterna de verdade).
  static ThemeMode next(ThemeMode current, [Brightness? resolvedBrightness]) {
    if (current == ThemeMode.system && resolvedBrightness != null) {
      return resolvedBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    }
    return switch (current) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
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

  static String styleLabel(ThemeStyle style) {
    return switch (style) {
      ThemeStyle.game => 'Jogo',
      ThemeStyle.premium => 'Premium',
      ThemeStyle.memo => 'Memo',
    };
  }
}
