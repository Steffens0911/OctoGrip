import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';

/// Exibe o asset da estante (ou fallback). No estilo premium usa cores do tema.
class ShelfBackground extends StatelessWidget {
  final String? imageAssetPath;
  final BoxFit fit;

  const ShelfBackground({
    super.key,
    this.imageAssetPath,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final isGameStyle =
        Theme.of(context).extension<AppThemeStyleExtension>()?.isGameStyle ?? true;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!isGameStyle) {
          final theme = Theme.of(context);
          return Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.scaffoldBackgroundColor,
                  theme.colorScheme.surfaceContainerHighest,
                ],
              ),
            ),
          );
        }
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2D1810),
                Color(0xFF1A0F0A),
              ],
            ),
          ),
          child: imageAssetPath != null && imageAssetPath!.isNotEmpty
              ? _buildImage()
              : _placeholder(),
        );
      },
    );
  }

  Widget _buildImage() {
    return Image.asset(
      imageAssetPath!,
      fit: fit,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF3D2817),
            Color(0xFF2D1810),
            Color(0xFF1A0F0A),
          ],
        ),
      ),
    );
  }
}
