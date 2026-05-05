// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

final _registered = <String>{};
final _iframesByVideoId = <String, html.IFrameElement>{};

/// Web: embed do YouTube via iframe.
/// O overlay transparente captura gestos: arrastar rola a página, tocar
/// envia play/pause via YouTube IFrame API (postMessage). O iframe nunca
/// recebe eventos de ponteiro diretamente (pointer-events: none).
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
    // enablejsapi=1 permite controle via postMessage
    final embedUrl =
        'https://www.youtube.com/embed/$videoId?rel=0&enablejsapi=1';
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
    onEnded: onEnded,
  );
}

/// No-op: com o overlay sempre ativo, o iframe nunca precisa de pointer-events.
void setYoutubePointerEvents({required String videoId, required bool enabled}) {}

class _YoutubeScrollableEmbed extends StatefulWidget {
  final String videoId;
  final String viewType;
  final double width;
  final double height;
  final VoidCallback? onEnded;

  const _YoutubeScrollableEmbed({
    required this.videoId,
    required this.viewType,
    required this.width,
    required this.height,
    this.onEnded,
  });

  @override
  State<_YoutubeScrollableEmbed> createState() =>
      _YoutubeScrollableEmbedState();
}

class _YoutubeScrollableEmbedState extends State<_YoutubeScrollableEmbed> {
  // playerState do YouTube: -1=uninit, 0=ended, 1=playing, 2=paused,
  // 3=buffering, 5=cued
  int _playerState = -1;
  html.EventListener? _msgListener;

  bool get _isPlaying => _playerState == 1 || _playerState == 3;

  @override
  void initState() {
    super.initState();
    _msgListener = _onWindowMessage;
    html.window.addEventListener('message', _msgListener!);
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _msgListener!);
    super.dispose();
  }

  void _onWindowMessage(html.Event event) {
    if (event is! html.MessageEvent) return;
    final raw = event.data;
    if (raw is! String) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ytEvent = map['event'] as String?;
      if (ytEvent == 'onStateChange') {
        final state = map['info'];
        if (state is int && mounted) {
          setState(() => _playerState = state);
          if (state == 0) widget.onEnded?.call();
        }
      }
    } catch (_) {}
  }

  void _sendCommand(String func) {
    _iframesByVideoId[widget.videoId]
        ?.contentWindow
        ?.postMessage('{"event":"command","func":"$func","args":""}', '*');
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _sendCommand('pauseVideo');
      if (mounted) setState(() => _playerState = 2);
    } else {
      _sendCommand('playVideo');
      if (mounted) setState(() => _playerState = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          HtmlElementView(viewType: widget.viewType),
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
              onTap: _togglePlayPause,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
