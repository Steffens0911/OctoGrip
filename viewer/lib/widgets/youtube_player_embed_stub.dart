import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre a URL fora do app (YouTube). Substituível em testes.
@visibleForTesting
Future<bool> Function(Uri uri) youtubeLauncher =
    (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// Tempo mínimo fora do app para considerar o vídeo assistido (evita liberar pontos num toque e volta).
@visibleForTesting
Duration youtubeMinAway = const Duration(seconds: 10);

/// Fora do web não há iframe: o toque abre o vídeo no YouTube e, ao voltar ao app depois de
/// [youtubeMinAway], chama [onEnded] (libera o botão de pontos na tela de vídeo de treino).
/// O servidor continua limitando a uma pontuação por vídeo por dia.
Widget buildYoutubeEmbed({
  required String videoId,
  required String videoUrl,
  required bool reelsMode,
  required double width,
  required double height,
  VoidCallback? onEnded,
}) {
  return _ExternalYoutubeLink(
    videoUrl: videoUrl,
    width: width,
    height: height,
    onEnded: onEnded,
  );
}

/// No-op fora do web.
void setYoutubePointerEvents(
    {required String videoId, required bool enabled}) {}

class _ExternalYoutubeLink extends StatefulWidget {
  const _ExternalYoutubeLink({
    required this.videoUrl,
    required this.width,
    required this.height,
    this.onEnded,
  });

  final String videoUrl;
  final double width;
  final double height;
  final VoidCallback? onEnded;

  @override
  State<_ExternalYoutubeLink> createState() => _ExternalYoutubeLinkState();
}

class _ExternalYoutubeLinkState extends State<_ExternalYoutubeLink>
    with WidgetsBindingObserver {
  DateTime? _openedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final openedAt = _openedAt;
    if (openedAt == null) return;
    _openedAt = null;
    if (DateTime.now().difference(openedAt) >= youtubeMinAway) {
      widget.onEnded?.call();
    }
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null) return;
    final ok = await youtubeLauncher(uri);
    if (!mounted) return;
    if (ok) {
      _openedAt = DateTime.now();
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o vídeo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final grey = Colors.grey.shade700;
    return Semantics(
      button: true,
      label: 'Assistir no YouTube',
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_outline,
                  size: 64, color: Colors.red),
              const SizedBox(height: 8),
              Text(
                'Toque para assistir no YouTube',
                style: TextStyle(color: grey, fontSize: 14),
              ),
              if (widget.onEnded != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Depois de assistir, volte ao app para liberar os pontos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
