import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/widgets/youtube_player_embed.dart';
import 'package:viewer/widgets/youtube_player_embed_stub.dart' as stub;

import '../helpers/pump_app.dart';

// Testes para YoutubePlayerEmbed (stub — não web).

void main() {
  setUpAll(disableGoogleFontsFetch);

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('YoutubePlayerEmbed', () {
    testWidgets('exibe placeholder quando videoUrl é null', (tester) async {
      await tester.pumpWidget(wrap(const YoutubePlayerEmbed(videoUrl: null)));
      await tester.pump();

      expect(find.text('Sem vídeo'), findsOneWidget);
      expect(find.byIcon(Icons.video_library), findsOneWidget);
    });

    testWidgets('exibe placeholder quando videoUrl é string vazia',
        (tester) async {
      await tester.pumpWidget(wrap(const YoutubePlayerEmbed(videoUrl: '')));
      await tester.pump();

      expect(find.text('Sem vídeo'), findsOneWidget);
    });

    testWidgets('exibe placeholder quando URL inválida', (tester) async {
      await tester.pumpWidget(
          wrap(const YoutubePlayerEmbed(videoUrl: 'nao-e-youtube')));
      await tester.pump();

      expect(find.text('Sem vídeo'), findsOneWidget);
    });

    testWidgets('renderiza conteúdo quando videoId válido (stub)',
        (tester) async {
      const url = 'https://youtu.be/dQw4w9WgXcQ';
      await tester.pumpWidget(wrap(const YoutubePlayerEmbed(videoUrl: url)));
      await tester.pump();

      // Em ambiente de teste (não-web), usa o stub que renderiza alguma coisa
      expect(find.text('Sem vídeo'), findsNothing);
    });
  });

  group('YoutubePlayerEmbed fora do web: abre o YouTube e libera ao voltar',
      () {
    const url = 'https://youtu.be/dQw4w9WgXcQ';
    late List<Uri> abertos;

    setUp(() {
      abertos = [];
      stub.youtubeLauncher = (uri) async {
        abertos.add(uri);
        return true;
      };
      stub.youtubeMinAway = Duration.zero;
    });

    tearDown(() => stub.youtubeMinAway = const Duration(seconds: 10));

    testWidgets('tocar abre a URL do vídeo fora do app', (tester) async {
      await tester.pumpWidget(wrap(const YoutubePlayerEmbed(videoUrl: url)));
      await tester.tap(find.text('Toque para assistir no YouTube'));
      await tester.pump();

      expect(abertos, [Uri.parse(url)]);
    });

    testWidgets('voltar ao app depois de abrir chama onEnded uma única vez',
        (tester) async {
      var fim = 0;
      await tester.pumpWidget(
          wrap(YoutubePlayerEmbed(videoUrl: url, onEnded: () => fim++)));
      await tester.tap(find.text('Toque para assistir no YouTube'));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(fim, 1);
    });

    testWidgets('sem ter aberto o vídeo, voltar ao app não libera nada',
        (tester) async {
      var fim = 0;
      await tester.pumpWidget(
          wrap(YoutubePlayerEmbed(videoUrl: url, onEnded: () => fim++)));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(fim, 0);
    });

    testWidgets('voltar rápido demais (menos que o mínimo) não libera',
        (tester) async {
      stub.youtubeMinAway = const Duration(minutes: 5);
      var fim = 0;
      await tester.pumpWidget(
          wrap(YoutubePlayerEmbed(videoUrl: url, onEnded: () => fim++)));
      await tester.tap(find.text('Toque para assistir no YouTube'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(fim, 0);
    });

    testWidgets('falha ao abrir mostra aviso e não libera', (tester) async {
      stub.youtubeLauncher = (_) async => false;
      var fim = 0;
      await tester.pumpWidget(
          wrap(YoutubePlayerEmbed(videoUrl: url, onEnded: () => fim++)));
      await tester.tap(find.text('Toque para assistir no YouTube'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(find.text('Não foi possível abrir o vídeo.'), findsOneWidget);
      expect(fim, 0);
    });
  });
}
