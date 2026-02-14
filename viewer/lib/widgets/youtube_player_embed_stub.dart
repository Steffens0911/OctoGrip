import 'package:flutter/material.dart';

/// Stub: em plataformas não-web mostra link para abrir no YouTube.
Widget buildYoutubeEmbed({
  required String videoId,
  required String videoUrl,
  required bool reelsMode,
  required double width,
  required double height,
}) {
  return InkWell(
    onTap: () {
      // url_launcher seria necessário para abrir; por simplicidade mostramos o link
    },
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_outline, size: 64, color: Colors.red),
          const SizedBox(height: 8),
          Text(
            'Assistir no YouTube',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          if (videoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                videoUrl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    ),
  );
}
