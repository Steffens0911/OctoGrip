import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/widgets/app_card.dart';
import 'package:viewer/widgets/app_navigation_tile.dart';
import 'package:viewer/widgets/execution_confirm_sheet.dart';
import 'package:viewer/widgets/partners_card.dart';

import '../helpers/pump_app.dart';

// Widgets de navegação e cards puros (StatelessWidget, sem API calls).

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppCard', () {
    testWidgets('renderiza com filho', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AppCard(child: Text('Conteúdo do card')),
        ),
      ));
      await tester.pump();

      expect(find.byType(AppCard), findsOneWidget);
      expect(find.text('Conteúdo do card'), findsOneWidget);
    });
  });

  group('AppNavigationTile', () {
    testWidgets('renderiza com título e subtítulo', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppNavigationTile(
            icon: Icons.home,
            title: 'Início',
            subtitle: 'Página principal',
            onTap: () => tapped = true,
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(AppNavigationTile), findsOneWidget);
      expect(find.text('Início'), findsOneWidget);
      expect(find.text('Página principal'), findsOneWidget);
    });

    testWidgets('chama onTap ao ser tocado', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppNavigationTile(
            icon: Icons.settings,
            title: 'Config',
            subtitle: 'Configurações',
            onTap: () => tapped = true,
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(AppNavigationTile));
      expect(tapped, isTrue);
    });

    testWidgets('exibe badge numérico quando badgeCount > 0', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppNavigationTile(
            icon: Icons.notifications,
            title: 'Notificações',
            subtitle: 'Novas mensagens',
            onTap: () {},
            badgeCount: 5,
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('exibe "99+" quando badgeCount > 99', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppNavigationTile(
            icon: Icons.mail,
            title: 'Mensagens',
            subtitle: 'Muitas mensagens',
            onTap: () {},
            badgeCount: 150,
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('exibe ícone de alerta quando showAlertBadge é true', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppNavigationTile(
            icon: Icons.warning,
            title: 'Atenção',
            subtitle: 'Há problemas',
            onTap: () {},
            showAlertBadge: true,
          ),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  group('PartnersCard', () {
    testWidgets('renderiza com título padrão', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PartnersCard(onTap: () {})),
      ));
      await tester.pump();

      expect(find.byType(PartnersCard), findsOneWidget);
      expect(find.textContaining('Parceiros'), findsWidgets);
    });

    testWidgets('renderiza com título customizado', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PartnersCard(title: 'Apoiadores', onTap: () {}),
        ),
      ));
      await tester.pump();

      expect(find.textContaining('Apoiadores'), findsWidgets);
    });
  });

  group('ExecutionConfirmSheet', () {
    testWidgets('abre sheet e exibe título de confirmação', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => ExecutionConfirmSheet.show(
                ctx,
                techniqueName: 'Armlock',
                opponentName: 'Pedro',
              ),
              child: const Text('Abrir sheet'),
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Abrir sheet'));
      await tester.pumpAndSettle();

      // O título é um Text normal, os nomes ficam em RichText
      expect(find.textContaining('Confirmar indicação'), findsWidgets);
    });

    testWidgets('exibe botões Cancelar e Confirmar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => ExecutionConfirmSheet.show(
                ctx,
                techniqueName: 'Kimura',
                opponentName: 'Lucas',
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Confirmar'), findsOneWidget);
    });
  });
}
