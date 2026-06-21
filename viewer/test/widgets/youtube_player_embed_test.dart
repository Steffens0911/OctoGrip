import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/widgets/youtube_player_embed.dart';

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

    testWidgets('exibe placeholder quando videoUrl é string vazia', (tester) async {
      await tester.pumpWidget(wrap(const YoutubePlayerEmbed(videoUrl: '')));
      await tester.pump();

      expect(find.text('Sem vídeo'), findsOneWidget);
    });

    testWidgets('exibe placeholder quando URL inválida', (tester) async {
      await tester.pumpWidget(wrap(const YoutubePlayerEmbed(videoUrl: 'nao-e-youtube')));
      await tester.pump();

      expect(find.text('Sem vídeo'), findsOneWidget);
    });

    testWidgets('renderiza conteúdo quando videoId válido (stub)', (tester) async {
      const url = 'https://youtu.be/dQw4w9WgXcQ';
      await tester.pumpWidget(wrap(const YoutubePlayerEmbed(videoUrl: url)));
      await tester.pump();

      // Em ambiente de teste (não-web), usa o stub que renderiza alguma coisa
      expect(find.text('Sem vídeo'), findsNothing);
    });
  });
}
