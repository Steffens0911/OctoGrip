/// Extrai o ID do vídeo de URLs do YouTube.
/// Suporta: youtube.com/watch?v=ID, www.youtube.com/..., youtu.be/ID, youtube.com/embed/ID
String? extractYouTubeVideoId(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final u = url.trim();
  // youtu.be/VIDEO_ID (pode ter ?query no final)
  final short = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})');
  final m1 = short.firstMatch(u);
  if (m1 != null) return m1.group(1);
  // youtube.com/watch?v=ID ou youtube.com/embed/ID (www. opcional)
  final long = RegExp(
    r'(?:www\.)?youtube\.com/(?:watch\?v=|embed/|shorts/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );
  final m2 = long.firstMatch(u);
  if (m2 != null) return m2.group(1);
  return null;
}

bool isYouTubeUrl(String? url) => extractYouTubeVideoId(url) != null;
