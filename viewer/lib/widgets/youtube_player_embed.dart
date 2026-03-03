import 'package:flutter/material.dart';

import 'package:viewer/utils/youtube_utils.dart';

import 'youtube_player_embed_stub.dart'
    if (dart.library.html) 'youtube_player_embed_web.dart' as impl;

/// Player de vídeo YouTube: embed (web) ou link (outras plataformas).
/// [reelsMode] = true usa aspect ratio vertical 9:16 (estilo shorts/reels).
/// [onEnded] é chamado quando o vídeo chega ao fim, se suportado pela plataforma.
class YoutubePlayerEmbed extends StatelessWidget {
  final String? videoUrl;
  final bool reelsMode;
  final VoidCallback? onEnded;

  const YoutubePlayerEmbed({
    super.key,
    required this.videoUrl,
    this.reelsMode = false,
    this.onEnded,
  });

  @override
  Widget build(BuildContext context) {
    final videoId = extractYouTubeVideoId(videoUrl);
    if (videoId == null || videoUrl == null || videoUrl!.isEmpty) {
      return Container(
        height: reelsMode ? 400 : 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.video_library, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Sem vídeo', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = screenWidth - 32;
    // Reels = vertical (9:16); normal = horizontal (16:9)
    final height = reelsMode
        ? (width * 16 / 9).clamp(320.0, MediaQuery.sizeOf(context).height * 0.8)
        : (width * 9 / 16).clamp(180.0, 400.0);

    return impl.buildYoutubeEmbed(
      videoId: videoId,
      videoUrl: videoUrl!,
      reelsMode: reelsMode,
      width: width,
      height: height,
      onEnded: onEnded,
    );
  }
}

