import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/presentation/widgets/technique_list_card.dart';
import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';
import 'package:viewer/features/trophies/presentation/state/trophy_list_state.dart';
import 'package:viewer/features/trophies/presentation/widgets/trophy_list_card.dart';

import '../helpers/pump_app.dart';

// Testes de widget para TechniqueListCard, TrophyListCard e TrophyListState.

TechniqueEntity _technique({String name = 'Triângulo', String id = 't1'}) =>
    TechniqueEntity(
      id: id,
      academyId: 'ac1',
      name: name,
      slug: 'triangulo',
      description: 'Finalização por triângulo',
    );

TrophyEntity _trophy({String name = 'Campeão', String id = 'tr1'}) =>
    TrophyEntity(
      id: id,
      academyId: 'ac1',
      techniqueId: 'tc1',
      name: name,
      startDateIso: '2024-06-01',
      endDateIso: '2024-06-30',
      targetCount: 10,
      awardKind: 'most_executions',
    );

void main() {
  setUpAll(disableGoogleFontsFetch);

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('TechniqueListCard', () {
    testWidgets('renderiza nome da técnica', (tester) async {
      bool editCalled = false;
      await tester.pumpWidget(wrap(TechniqueListCard(
        entity: _technique(),
        onEdit: () => editCalled = true,
        onDelete: () {},
      )));

      expect(find.text('Triângulo'), findsOneWidget);
    });

    testWidgets('toque chama onEdit quando canEdit=true', (tester) async {
      bool editCalled = false;
      await tester.pumpWidget(wrap(TechniqueListCard(
        entity: _technique(),
        onEdit: () => editCalled = true,
        onDelete: () {},
      )));

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      expect(editCalled, isTrue);
    });

    testWidgets('toque não chama onEdit quando canEdit=false', (tester) async {
      bool editCalled = false;
      await tester.pumpWidget(wrap(TechniqueListCard(
        entity: _technique(),
        onEdit: () => editCalled = true,
        onDelete: () {},
        canEdit: false,
      )));

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      expect(editCalled, isFalse);
    });
  });

  group('TrophyListCard', () {
    testWidgets('renderiza nome do troféu', (tester) async {
      await tester.pumpWidget(wrap(TrophyListCard(
        entity: _trophy(),
        onEdit: () {},
        onDelete: () {},
      )));

      expect(find.text('Campeão'), findsOneWidget);
    });

    testWidgets('exibe datas e meta na descrição', (tester) async {
      await tester.pumpWidget(wrap(TrophyListCard(
        entity: _trophy(),
        onEdit: () {},
        onDelete: () {},
      )));

      final text = find.textContaining('2024-06-01');
      expect(text, findsWidgets);
    });
  });

  group('TrophyListState', () {
    test('filtered retorna todos os itens quando query vazia', () {
      final state = TrophyListState(
        academyId: 'ac1',
        allItems: [_trophy(name: 'Alfa'), _trophy(name: 'Beta', id: 'tr2')],
        searchQuery: '',
      );

      expect(state.filtered.length, 2);
    });

    test('filtered filtra por nome', () {
      final state = TrophyListState(
        academyId: 'ac1',
        allItems: [_trophy(name: 'Alfa'), _trophy(name: 'Beta', id: 'tr2')],
        searchQuery: 'alfa',
      );

      expect(state.filtered.length, 1);
      expect(state.filtered.first.name, 'Alfa');
    });

    test('visible respeita visibleCount', () {
      final items = List.generate(30, (i) => _trophy(name: 'T$i', id: 'tr$i'));
      final state = TrophyListState(
        academyId: 'ac1',
        allItems: items,
        visibleCount: 10,
      );

      expect(state.visible.length, 10);
    });

    test('hasMore true quando há mais itens além do visível', () {
      final items = List.generate(30, (i) => _trophy(name: 'T$i', id: 'tr$i'));
      final state = TrophyListState(
        academyId: 'ac1',
        allItems: items,
        visibleCount: 10,
      );

      expect(state.hasMore, isTrue);
    });

    test('hasMore false quando todos os itens são visíveis', () {
      final state = TrophyListState(
        academyId: 'ac1',
        allItems: [_trophy()],
        visibleCount: 20,
      );

      expect(state.hasMore, isFalse);
    });
  });
}
