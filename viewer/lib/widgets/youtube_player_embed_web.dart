// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

final _registered = <String>{};

/// Web: embed do YouTube via iframe (permite modo reels com aspect ratio vertical).
Widget buildYoutubeEmbed({
  required String videoId,
  required String videoUrl,
  required bool reelsMode,
  required double width,
  required double height,
}) {
  final viewType = 'youtube_embed_$videoId';
  if (!_registered.contains(videoId)) {
    _registered.add(videoId);
    final embedUrl = 'https://www.youtube.com/embed/$videoId?rel=0';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = embedUrl
        ..style.border = 'none'
        ..width = '100%'
        ..height = '100%'
        ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
        ..allowFullscreen = true;
      return iframe;
    });
  }
  return PointerInterceptor(
    child: SizedBox(
      width: width,
      height: height,
      child: HtmlElementView(viewType: viewType),
    ),
  );
}
