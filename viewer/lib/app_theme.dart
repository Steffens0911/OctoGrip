import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:viewer/services/theme_service.dart';

/// Extensão do tema para indicar o estilo visual: jogo, premium ou memo (Memo UI Kit).
class AppThemeStyleExtension extends ThemeExtension<AppThemeStyleExtension> {
  final ThemeStyle style;

  const AppThemeStyleExtension({required this.style});

  bool get isGameStyle => style == ThemeStyle.game;
  bool get isMemoStyle => style == ThemeStyle.memo;

  @override
  AppThemeStyleExtension copyWith({ThemeStyle? style}) =>
      AppThemeStyleExtension(style: style ?? this.style);

  @override
  AppThemeStyleExtension lerp(
      ThemeExtension<AppThemeStyleExtension>? other, double t) {
    if (other is! AppThemeStyleExtension) return this;
    return AppThemeStyleExtension(style: t < 0.5 ? style : other.style);
  }
}

/// Tema estilo jogo — fundo marrom em gradiente, destaques âmbar/dourado.
class AppTheme {
  /// Breakpoint para layout responsivo (tablet/desktop).
  static const double breakpointTablet = 600;
  static const double breakpointDesktop = 900;
  static const double maxContentWidth = 720;

  /// Padding lateral responsivo: menor em mobile, maior em telas largas.
  static double screenPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < breakpointTablet) return 16;
    if (w < breakpointDesktop) return 20;
    return 24;
  }

  /// Retorna true se a tela for considerada estreita (mobile).
  static bool isNarrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < breakpointTablet;

  // Paleta game-like (estante de troféus)
  static const Color primary = Color(0xFFD4A017); // Âmbar/dourado
  static const Color primaryLight = Color(0xFFE8B82E);
  static const Color primaryDark = Color(0xFFB8860B);
  static const Color accent = Color(0xFFF0C14B); // Destaque claro

  /// Cor do AppBar e topo do gradiente (marrom escuro).
  static const Color shelfBrown = Color(0xFF2D1810);
  /// Base do gradiente (mais escuro).
  static const Color shelfBrownDark = Color(0xFF1A0F0A);
  /// Marrom médio (cards, superfícies).
  static const Color shelfBrownMid = Color(0xFF3D2817);
  static const Color shelfBrownCard = Color(0xFF4A3328);

  // Light (game-style): tema claro em tons suaves, inspirado no layout coffee shop.
  static const Color background = Color(0xFFF7F9F4); // fundo bem claro
  static const Color surface = Color(0xFFFFFFFF); // cartões brancos
  static const Color surfaceElevated = Color(0xFFE3F0D3); // blocos levemente esverdeados
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF253319); // texto verde bem escuro
  static const Color textSecondary = Color(0xFF5C6B45);
  static const Color textMuted = Color(0xFF8A9A6C);
  static const Color border = Color(0xFFD1E0B9);
  static const Color borderLight = Color(0xFFE4F0CF);

  // Dark (game-style: igual à estante)
  static const Color backgroundDark = Color(0xFF2D1810);
  static const Color surfaceDark = Color(0xFF2D1810);
  static const Color surfaceElevatedDark = Color(0xFF3D2817);
  static const Color cardBackgroundDark = Color(0xFF3D2817);
  static const Color textPrimaryDark = Color(0xFFF5F0E8);
  static const Color textSecondaryDark = Color(0xFFD4C4B0);
  static const Color textMutedDark = Color(0xFFA09080);
  static const Color borderDark = Color(0xFF4A3328);
  static const Color borderLightDark = Color(0xFF5C4033);

  /// Cores sensíveis ao tema atual. Respeita brilho (light/dark) e estilo
  /// (jogo / premium / memo) via [AppThemeStyleExtension].
  static Color backgroundOf(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.extension<AppThemeStyleExtension>()?.style ?? ThemeStyle.game;
    final isDark = theme.brightness == Brightness.dark;
    if (style == ThemeStyle.memo) return isDark ? memoBackgroundDark : memoBackground;
    if (style == ThemeStyle.premium) return isDark ? premiumBackgroundDark : premiumBackground;
    return isDark ? backgroundDark : background;
  }

  static Color surfaceOf(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.extension<AppThemeStyleExtension>()?.style ?? ThemeStyle.game;
    final isDark = theme.brightness == Brightness.dark;
    if (style == ThemeStyle.memo) return isDark ? memoSurfaceDark : memoSurface;
    if (style == ThemeStyle.premium) return isDark ? premiumSurfaceDark : premiumSurface;
    return isDark ? surfaceDark : surface;
  }

  static Color textPrimaryOf(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.extension<AppThemeStyleExtension>()?.style ?? ThemeStyle.game;
    final isDark = theme.brightness == Brightness.dark;
    if (style == ThemeStyle.memo) return isDark ? memoTextPrimaryDark : memoTextPrimary;
    if (style == ThemeStyle.premium) return isDark ? premiumTextPrimaryDark : premiumTextPrimary;
    return isDark ? textPrimaryDark : textPrimary;
  }

  static Color textSecondaryOf(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.extension<AppThemeStyleExtension>()?.style ?? ThemeStyle.game;
    final isDark = theme.brightness == Brightness.dark;
    if (style == ThemeStyle.memo) return isDark ? memoTextSecondaryDark : memoTextSecondary;
    if (style == ThemeStyle.premium) return isDark ? premiumTextSecondaryDark : premiumTextSecondary;
    return isDark ? textSecondaryDark : textSecondary;
  }

  static Color textMutedOf(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.extension<AppThemeStyleExtension>()?.style ?? ThemeStyle.game;
    final isDark = theme.brightness == Brightness.dark;
    if (style == ThemeStyle.memo) return isDark ? memoTextMutedDark : memoTextMuted;
    if (style == ThemeStyle.premium) return isDark ? premiumTextMutedDark : premiumTextMuted;
    return isDark ? textMutedDark : textMuted;
  }

  static Color borderOf(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.extension<AppThemeStyleExtension>()?.style ?? ThemeStyle.game;
    final isDark = theme.brightness == Brightness.dark;
    if (style == ThemeStyle.memo) return isDark ? memoBorderDark : memoBorder;
    if (style == ThemeStyle.premium) return isDark ? premiumBorderDark : premiumBorder;
    return isDark ? borderDark : border;
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: const Color(0xFF1A0F0A),
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceElevated,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).copyWith(
        displaySmall: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 1,
        shadowColor: const Color(0x14000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF1A0F0A),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF1A0F0A),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Color(0xFF1A0F0A),
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      extensions: const [AppThemeStyleExtension(style: ThemeStyle.game)],
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: Colors.white,
        surface: surfaceDark,
        onSurface: textPrimaryDark,
        surfaceContainerHighest: surfaceElevatedDark,
        outline: borderDark,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
        displaySmall: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimaryDark,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: textPrimaryDark,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: textSecondaryDark,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: shelfBrown,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackgroundDark,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: borderDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      extensions: const [AppThemeStyleExtension(style: ThemeStyle.game)],
    );
  }

  // --- Paleta Memo UI Kit (tema escuro roxo/verde) ---
  static const Color memoPrimary = Color(0xFF49AB6C); // P500
  static const Color memoPrimaryLight = Color(0xFF60D88B); // P400
  static const Color memoSecondary = Color(0xFF9C81EA); // S400
  static const Color memoBackground = Color(0xFF252330); // claro: variante suave
  static const Color memoBackgroundDark = Color(0xFF1F1D28); // N900
  static const Color memoSurface = Color(0xFF2A2835);
  static const Color memoSurfaceDark = Color(0xFF343141); // N800
  static const Color memoSurfaceElevatedDark = Color(0xFF4A465B); // N700
  static const Color memoTextPrimary = Color(0xFF343141);
  static const Color memoTextPrimaryDark = Color(0xFFFFFFFF);
  static const Color memoTextSecondary = Color(0xFF7A748E); // N500
  static const Color memoTextSecondaryDark = Color(0xFFC7C3DB); // N200
  static const Color memoTextMuted = Color(0xFF928CA6); // N400
  static const Color memoTextMutedDark = Color(0xFFADA7C1); // N300
  static const Color memoBorder = Color(0xFF4A465B);
  static const Color memoBorderDark = Color(0xFF343141);
  static const Color memoDanger = Color(0xFFE63D70); // D500

  // --- Paleta premium (tema claro verde estilo coffee shop) ---
  static const Color premiumPrimary = Color(0xFF6CB238); // verde principal
  static const Color premiumPrimaryLight = Color(0xFF8FD45A);
  static const Color premiumPrimaryDark = Color(0xFF4E8A26);
  static const Color premiumBackground = Color(0xFFF7F9F4); // fundo cinza-esverdeado bem claro
  static const Color premiumBackgroundWarm = Color(0xFFE9F4D9); // blocos verdes suaves
  static const Color premiumSurface = Color(0xFFFFFFFF); // cartões brancos
  static const Color premiumSurfaceVariant = Color(0xFFE3F0D3); // cartões verdes claros
  /// Texto primário em fundo claro.
  static const Color premiumTextPrimary = Color(0xFF253319);
  /// Texto secundário/leves legendas.
  static const Color premiumTextSecondary = Color(0xFF5C6B45);
  static const Color premiumTextMuted = Color(0xFF8A9A6C);
  static const Color premiumBorder = Color(0xFFD1E0B9);
  static const Color premiumBorderAccent = Color(0xFFC0D89C);
  static const Color premiumBackgroundDark = Color(0xFF111915);
  static const Color premiumSurfaceDark = Color(0xFF19261F);
  static const Color premiumSurfaceElevatedDark = Color(0xFF223227);
  static const Color premiumTextPrimaryDark = Color(0xFFF4F7ED);
  static const Color premiumTextSecondaryDark = Color(0xFFB5C4A2);
  static const Color premiumTextMutedDark = Color(0xFF8EA080);
  static const Color premiumBorderDark = Color(0xFF304130);

  static ThemeData get premiumLight {
    const colorScheme = ColorScheme.light(
      primary: premiumPrimary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEDE9FE),
      onPrimaryContainer: premiumPrimaryDark,
      secondary: premiumTextSecondary,
      onSecondary: premiumSurface,
      secondaryContainer: premiumSurfaceVariant,
      onSecondaryContainer: premiumTextPrimary,
      tertiary: premiumPrimaryLight,
      onTertiary: Colors.white,
      error: Color(0xFFB91C1C),
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: premiumSurface,
      onSurface: premiumTextPrimary,
      onSurfaceVariant: premiumTextSecondary,
      outline: premiumBorder,
      outlineVariant: Color(0xFFF1F5F9),
      surfaceContainerHighest: premiumSurfaceVariant,
      surfaceContainerLow: premiumBackground,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: premiumTextPrimary,
      onInverseSurface: premiumSurface,
      inversePrimary: Color(0xFFEDE9FE),
      surfaceTint: premiumPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: premiumBackground,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).copyWith(
        displaySmall: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: premiumTextPrimary,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: premiumTextPrimary,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: premiumTextPrimary,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: premiumTextPrimary,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: premiumTextPrimary,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: premiumTextSecondary,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: premiumTextPrimary,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: premiumTextSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: premiumSurface,
        foregroundColor: premiumTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: premiumTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: premiumSurface,
        elevation: 1,
        shadowColor: const Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: premiumBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: premiumPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: premiumPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: premiumPrimary,
          side: const BorderSide(color: premiumPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: premiumPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: premiumSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: premiumBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: premiumPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      extensions: const [AppThemeStyleExtension(style: ThemeStyle.premium)],
    );
  }

  static ThemeData get premiumDark {
    const colorSchemeDark = ColorScheme.dark(
      primary: premiumPrimaryLight,
      onPrimary: premiumBackgroundDark,
      primaryContainer: premiumSurfaceElevatedDark,
      onPrimaryContainer: premiumTextPrimaryDark,
      secondary: premiumTextSecondaryDark,
      onSecondary: premiumSurfaceDark,
      secondaryContainer: premiumBorderDark,
      onSecondaryContainer: premiumTextPrimaryDark,
      tertiary: premiumPrimaryLight,
      onTertiary: premiumBackgroundDark,
      error: Color(0xFFF87171),
      onError: Color(0xFF7F1D1D),
      errorContainer: Color(0xFFB91C1C),
      onErrorContainer: Color(0xFFFEE2E2),
      surface: premiumSurfaceDark,
      onSurface: premiumTextPrimaryDark,
      onSurfaceVariant: premiumTextSecondaryDark,
      outline: premiumBorderDark,
      outlineVariant: Color(0xFF3730A3),
      surfaceContainerHighest: premiumSurfaceElevatedDark,
      surfaceContainerLow: premiumBackgroundDark,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: premiumTextPrimaryDark,
      onInverseSurface: premiumSurfaceDark,
      inversePrimary: premiumPrimaryDark,
      surfaceTint: premiumPrimaryLight,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorSchemeDark,
      scaffoldBackgroundColor: premiumBackgroundDark,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
        displaySmall: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: premiumTextPrimaryDark,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: premiumTextPrimaryDark,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: premiumTextPrimaryDark,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: premiumTextPrimaryDark,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: premiumTextPrimaryDark,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: premiumTextSecondaryDark,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: premiumTextPrimaryDark,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: premiumTextSecondaryDark,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: premiumSurfaceDark,
        foregroundColor: premiumTextPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: premiumTextPrimaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: premiumSurfaceDark,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: premiumBorderDark, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: premiumPrimaryLight,
          foregroundColor: premiumBackgroundDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: premiumPrimaryLight,
          foregroundColor: premiumBackgroundDark,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: premiumPrimaryLight,
          side: const BorderSide(color: premiumPrimaryLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: premiumPrimaryLight,
        foregroundColor: premiumBackgroundDark,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: premiumSurfaceDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: premiumBorderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: premiumPrimaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      extensions: const [AppThemeStyleExtension(style: ThemeStyle.premium)],
    );
  }

  static ThemeData get memoLight {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: memoPrimary,
      primary: memoPrimary,
      onPrimary: Colors.white,
      secondary: memoSecondary,
      surface: memoSurface,
      onSurface: memoTextPrimary,
      surfaceContainerHighest: memoSurfaceDark,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: memoBackground,
      fontFamily: GoogleFonts.robotoMono().fontFamily,
      textTheme: GoogleFonts.robotoMonoTextTheme(ThemeData.light().textTheme).copyWith(
        displaySmall: GoogleFonts.robotoMono(fontSize: 28, fontWeight: FontWeight.w700, color: memoTextPrimary),
        headlineMedium: GoogleFonts.robotoMono(fontSize: 22, fontWeight: FontWeight.w600, color: memoTextPrimary),
        titleLarge: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.w600, color: memoTextPrimary),
        titleMedium: GoogleFonts.robotoMono(fontSize: 16, fontWeight: FontWeight.w600, color: memoTextPrimary),
        bodyLarge: GoogleFonts.robotoMono(fontSize: 16, color: memoTextPrimary),
        bodyMedium: GoogleFonts.robotoMono(fontSize: 14, color: memoTextSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: memoSurface,
        foregroundColor: memoTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.w600, color: memoTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: memoSurfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: memoBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: memoPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.robotoMono(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: memoPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.robotoMono(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: memoSecondary,
          side: const BorderSide(color: memoSecondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: memoSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: memoBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: memoPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: memoDanger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      extensions: const [AppThemeStyleExtension(style: ThemeStyle.memo)],
    );
  }

  static ThemeData get memoDark {
    final colorScheme = ColorScheme.dark(
      primary: memoPrimaryLight,
      onPrimary: memoBackgroundDark,
      secondary: memoSecondary,
      surface: memoSurfaceDark,
      onSurface: memoTextPrimaryDark,
      surfaceContainerHighest: memoSurfaceElevatedDark,
      outline: memoBorderDark,
      error: memoDanger,
      onError: Colors.white,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: memoBackgroundDark,
      fontFamily: GoogleFonts.robotoMono().fontFamily,
      textTheme: GoogleFonts.robotoMonoTextTheme(ThemeData.dark().textTheme).copyWith(
        displaySmall: GoogleFonts.robotoMono(fontSize: 28, fontWeight: FontWeight.w700, color: memoTextPrimaryDark),
        headlineMedium: GoogleFonts.robotoMono(fontSize: 22, fontWeight: FontWeight.w600, color: memoTextPrimaryDark),
        titleLarge: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.w600, color: memoTextPrimaryDark),
        titleMedium: GoogleFonts.robotoMono(fontSize: 16, fontWeight: FontWeight.w600, color: memoTextPrimaryDark),
        bodyLarge: GoogleFonts.robotoMono(fontSize: 16, color: memoTextPrimaryDark),
        bodyMedium: GoogleFonts.robotoMono(fontSize: 14, color: memoTextSecondaryDark),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: memoBackgroundDark,
        foregroundColor: memoTextPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.w600, color: memoTextPrimaryDark),
      ),
      cardTheme: CardThemeData(
        color: memoSurfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: memoBorderDark, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: memoPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.robotoMono(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: memoPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.robotoMono(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: memoSecondary,
          side: const BorderSide(color: memoSecondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: memoSurfaceDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: memoBorderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: memoPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: memoDanger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      extensions: const [AppThemeStyleExtension(style: ThemeStyle.memo)],
    );
  }
}
