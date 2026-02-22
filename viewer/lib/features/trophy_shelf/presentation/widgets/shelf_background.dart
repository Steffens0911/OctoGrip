import 'package:flutter/material.dart';

/// Exibe o asset da estante (ou fallback). Cuida de aspect ratio e responsividade.
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF2D1810),
                const Color(0xFF1A0F0A),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF3D2817),
            const Color(0xFF2D1810),
            const Color(0xFF1A0F0A),
          ],
        ),
      ),
    );
  }
}
