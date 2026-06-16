import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/mission_today.dart';
import 'package:viewer/widgets/gamification/weekly_mission_path.dart';

import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MissionToday _mission({
  String missionId = 'm1',
  String title = 'Armlock 5x',
  bool completed = false,
}) =>
    MissionToday(
      missionId: missionId,
      missionTitle: title,
      lessonTitle: 'Lição de $title',
      description: 'Finalize $title',
      videoUrl: 'https://youtube.com/watch?v=test',
      positionName: 'Montada',
      techniqueName: title,
      alreadyCompleted: completed,
    );

MissionWeekSlot _slot({
  String label = 'Seg',
  MissionToday? mission,
}) =>
    MissionWeekSlot(periodLabel: label, mission: mission);

Widget _path(List<MissionWeekSlot> slots, {String? celebrateMissionId}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: WeeklyMissionPath(
            slots: slots,
            celebrateMissionId: celebrateMissionId,
          ),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  setUpAll(disableGoogleFontsFetch);

  // O widget tem 2 fileiras: _PathRow (topo) + _StatusRow (bottom).
  // _PathRow: lock_outline_rounded / play_arrow_rounded / check_rounded
  // _StatusRow: lock_outline_rounded / radio_button_unchecked_rounded / check_rounded
  // Logo cada slot contribui com 2 instâncias de ícone (uma por fileira).

  group('WeeklyMissionPath — renderização básica', () {
    testWidgets('renderiza sem slots sem crash (SizedBox.shrink)', (tester) async {
      await tester.pumpWidget(_path([]));
      await tester.pump();
      expect(find.byType(WeeklyMissionPath), findsOneWidget);
      // Sem slots, renderiza SizedBox.shrink — nenhum ícone
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    });

    testWidgets('slot vazio (sem missão) → 2× lock_outline_rounded', (tester) async {
      await tester.pumpWidget(_path([_slot()]));
      await tester.pumpAndSettle();
      // PathRow + StatusRow = 2 instâncias do ícone de cadeado
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
    });

    testWidgets('slot com missão disponível → play_arrow e radio_button', (tester) async {
      final slots = [_slot(label: 'Seg', mission: _mission())];
      await tester.pumpWidget(_path(slots));
      await tester.pumpAndSettle();
      // PathRow: play_arrow_rounded; StatusRow: radio_button_unchecked_rounded
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
    });

    testWidgets('slot com missão concluída → 2× check_rounded', (tester) async {
      final slots = [
        _slot(label: 'Seg', mission: _mission(missionId: 'm-done', completed: true)),
      ];
      await tester.pumpWidget(_path(slots));
      await tester.pumpAndSettle();
      // PathRow + StatusRow
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });

    testWidgets('renderiza múltiplos slots', (tester) async {
      final slots = [
        _slot(label: 'Seg'),
        _slot(label: 'Ter'),
        _slot(label: 'Qua'),
      ];
      await tester.pumpWidget(_path(slots));
      await tester.pumpAndSettle();
      // 3 slots vazios = 3×2 = 6 ícones de cadeado
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(6));
    });
  });

  group('WeeklyMissionPath — rótulos', () {
    testWidgets('mostra periodLabel como fallback quando técnica está vazia', (tester) async {
      // Quando techniqueName='' e lessonTitle='', _TechniqueRow usa periodLabel
      final slots = [
        MissionWeekSlot(
          periodLabel: 'Seg',
          mission: MissionToday(
            missionTitle: 'Missão',
            lessonTitle: '',
            description: 'desc',
            videoUrl: 'url',
            positionName: 'pos',
            techniqueName: '',
          ),
        ),
      ];
      await tester.pumpWidget(_path(slots));
      await tester.pumpAndSettle();
      expect(find.text('Seg'), findsOneWidget);
    });

    testWidgets('mostra nome da técnica da missão', (tester) async {
      final slots = [
        _slot(label: 'Seg', mission: _mission(title: 'Triângulo Invertido')),
      ];
      await tester.pumpWidget(_path(slots));
      await tester.pumpAndSettle();
      expect(find.textContaining('Triângulo'), findsWidgets);
    });

    testWidgets('slot vazio mostra "—" na fileira de técnicas', (tester) async {
      final slots = [_slot(label: 'Seg')]; // sem missão
      await tester.pumpWidget(_path(slots));
      await tester.pumpAndSettle();
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('WeeklyMissionPath — semana completa', () {
    testWidgets('5 slots mistos — ícones corretos em cada fileira', (tester) async {
      final slots = [
        _slot(label: 'Seg', mission: _mission(missionId: 'm1', completed: true)),
        _slot(label: 'Ter', mission: _mission(missionId: 'm2', completed: true)),
        _slot(label: 'Qua', mission: _mission(missionId: 'm3', completed: false)),
        _slot(label: 'Qui', mission: _mission(missionId: 'm4', completed: false)),
        _slot(label: 'Sex'),
      ];
      await tester.pumpWidget(_path(slots));
      await tester.pumpAndSettle();

      // 2 concluídas × 2 fileiras = 4 checks
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(4));
      // 2 disponíveis × 1 (só PathRow usa play_arrow) = 2
      expect(find.byIcon(Icons.play_arrow_rounded), findsNWidgets(2));
      // 1 bloqueado × 2 fileiras = 2
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
    });
  });

  group('WeeklyMissionPath — rótulos de status', () {
    testWidgets('missão concluída mostra label "Feito"', (tester) async {
      await tester.pumpWidget(_path([
        _slot(label: 'Seg', mission: _mission(completed: true)),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Feito'), findsOneWidget);
    });

    testWidgets('missão disponível mostra label "Treinar"', (tester) async {
      await tester.pumpWidget(_path([
        _slot(label: 'Seg', mission: _mission(completed: false)),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Treinar'), findsOneWidget);
    });

    testWidgets('slot vazio mostra label "Bloqueado"', (tester) async {
      await tester.pumpWidget(_path([_slot(label: 'Seg')]));
      await tester.pumpAndSettle();
      expect(find.text('Bloqueado'), findsOneWidget);
    });
  });

  group('WeeklyMissionPath — animação de celebração', () {
    testWidgets('celebrateMissionId não causa crash', (tester) async {
      final slots = [
        _slot(label: 'Seg', mission: _mission(missionId: 'm1', completed: true)),
      ];
      await tester.pumpWidget(_path(slots, celebrateMissionId: 'm1'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(WeeklyMissionPath), findsOneWidget);
    });
  });
}
