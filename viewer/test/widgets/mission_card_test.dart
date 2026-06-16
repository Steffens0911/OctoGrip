import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/widgets/mission_card.dart';

import '../helpers/pump_app.dart';

void main() {
  setUpAll(disableGoogleFontsFetch);

  group('MissionCard', () {
    testWidgets('exibe título e descrição padrão sem parâmetros', (tester) async {
      await tester.pumpWidget(wrapApp(const MissionCard()));

      expect(find.text('Centro de treinamento'), findsOneWidget);
      expect(find.textContaining('missões'), findsWidgets);
      expect(find.text('Ver missão'), findsOneWidget);
    });

    testWidgets('exibe título, descrição e label do botão personalizados', (tester) async {
      await tester.pumpWidget(wrapApp(const MissionCard(
        title: 'Treino Avançado',
        description: 'Faixa preta a caminho.',
        buttonLabel: 'Iniciar',
      )));

      expect(find.text('Treino Avançado'), findsOneWidget);
      expect(find.text('Faixa preta a caminho.'), findsOneWidget);
      expect(find.text('Iniciar'), findsOneWidget);
    });

    testWidgets('dispara onTap ao tocar no botão', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapApp(MissionCard(onTap: () => tapped = true)));

      await tester.tap(find.text('Ver missão'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('não lança exceção quando onTap é nulo', (tester) async {
      await tester.pumpWidget(wrapApp(const MissionCard()));
      await tester.tap(find.text('Ver missão'));
      await tester.pump();
      // Sem crash.
    });

    testWidgets('renderiza o ícone do escudo', (tester) async {
      await tester.pumpWidget(wrapApp(const MissionCard()));
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });
  });
}
