// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

final _registered = <String>{};
final _iframesByVideoId = <String, html.IFrameElement>{};
final _interactingByVideoId = <String, ValueNotifier<bool>>{};

ValueNotifier<bool> _interactingNotifier(String videoId) =>
    _interactingByVideoId.putIfAbsent(videoId, () => ValueNotifier(false));

/// Web: embed do YouTube via iframe.
/// Começa em modo scroll (pointer-events: none); toque ativa os controles.
Widget buildYoutubeEmbed({
  required String videoId,
  required String videoUrl,
  required bool reelsMode,
  required double width,
  required double height,
  VoidCallback? onEnded,
}) {
  final viewType = 'youtube_embed_$videoId';
  if (!_registered.contains(videoId)) {
    _registered.add(videoId);
    final embedUrl = 'https://www.youtube.com/embed/$videoId?rel=0';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = embedUrl
        ..style.border = 'none'
        ..style.pointerEvents = 'none'
        ..width = '100%'
        ..height = '100%'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
        ..allowFullscreen = true;
      _iframesByVideoId[videoId] = iframe;
      return iframe;
    });
  }
  return _YoutubeScrollableEmbed(
    videoId: videoId,
    viewType: viewType,
    width: width,
    height: height,
  );
}

/// Controla se o iframe pode receber eventos de mouse/scroll (sincroniza widget + iframe).
void setYoutubePointerEvents({required String videoId, required bool enabled}) {
  final iframe = _iframesByVideoId[videoId];
  if (iframe != null) {
    iframe.style.pointerEvents = enabled ? 'auto' : 'none';
  }
  _interactingNotifier(videoId).value = enabled;
}

class _YoutubeScrollableEmbed extends StatefulWidget {
  final String videoId;
  final String viewType;
  final double width;
  final double height;

  const _YoutubeScrollableEmbed({
    required this.videoId,
    required this.viewType,
    required this.width,
    required this.height,
  });

  @override
  State<_YoutubeScrollableEmbed> createState() =>
      _YoutubeScrollableEmbedState();
}

class _YoutubeScrollableEmbedState extends State<_YoutubeScrollableEmbed> {
  late final ValueNotifier<bool> _interacting;

  @override
  void initState() {
    super.initState();
    _interacting = _interactingNotifier(widget.videoId);
  }

  void _setInteracting(bool value) {
    final iframe = _iframesByVideoId[widget.videoId];
    if (iframe != null) {
      iframe.style.pointerEvents = value ? 'auto' : 'none';
    }
    _interacting.value = value;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ValueListenableBuilder<bool>(
        valueListenable: _interacting,
        builder: (context, interacting, _) {
          return Stack(
            children: [
              HtmlElementView(viewType: widget.viewType),

              // Modo scroll: overlay transparente captura gestos verticais e
              // repassa para o SingleChildScrollView pai.
              if (!interacting)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      final scrollable = Scrollable.maybeOf(context);
                      if (scrollable == null) return;
                      final pos = scrollable.position;
                      pos.jumpTo(
                        (pos.pixels - details.delta.dy)
                            .clamp(pos.minScrollExtent, pos.maxScrollExtent),
                      );
                    },
                    onTap: () => _setInteracting(true),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _Badge(
                          icon: Icons.touch_app,
                          label: 'Toque p/ controlar',
                        ),
                      ),
                    ),
                  ),
                ),

              // Modo interação: badge para voltar ao modo scroll.
              if (interacting)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _setInteracting(false),
                    child: _Badge(icon: Icons.swap_vert, label: 'Rolar'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
