import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/manual_trophy.dart';
import 'package:viewer/models/trophy.dart';

void main() {
  group('TrophyWithEarned.fromJson', () {
    test('mapeia campos numéricos vindos como num e aplica defaults', () {
      final json = {
        'trophy_id': 'tr1',
        'technique_id': 'tec1',
        'name': 'Mestre da Raspagem',
        'start_date': '2026-01-01',
        'end_date': '2026-01-31',
        'target_count': 10,
        'gold_count': 2,
        'silver_count': 1,
        'earned_tier': 'gold',
      };

      final t = TrophyWithEarned.fromJson(json);

      expect(t.trophyId, 'tr1');
      expect(t.targetCount, 10);
      expect(t.goldCount, 2);
      expect(t.silverCount, 1);
      expect(t.bronzeCount, 0); // default
      expect(t.awardKind, 'trophy'); // default
      expect(t.unlocked, isTrue); // default
      expect(t.earnedTier, 'gold');
      expect(t.isManualAward, isFalse);
    });

    test('fromManualAward mapeia concessão de campeonato como medalha', () {
      final award = TrophyAward(
        id: 'a1',
        templateId: 'tpl1',
        templateName: 'Campeão Estadual',
        userId: 'u1',
        awardedAt: '2026-03-10',
        trophyType: 'championship',
        medalType: 'gold',
        note: 'Parabéns!',
        championshipEventName: 'Open SP',
      );

      final t = TrophyWithEarned.fromManualAward(award);

      expect(t.isManualAward, isTrue);
      expect(t.awardKind, 'medal');
      expect(t.isMedal, isTrue);
      expect(t.earnedTier, 'gold');
      expect(t.awardNote, 'Parabéns!');
      expect(t.championshipEventName, 'Open SP');
    });
  });

  group('TrophyWithEarned helpers', () {
    test('tierEmoji cobre todos os tiers e fallback', () {
      expect(TrophyWithEarned.tierEmoji('gold'), '🥇');
      expect(TrophyWithEarned.tierEmoji('silver'), '🥈');
      expect(TrophyWithEarned.tierEmoji('bronze'), '🥉');
      expect(TrophyWithEarned.tierEmoji('participation'), '🎖️');
      expect(TrophyWithEarned.tierEmoji(null), '🏆');
      expect(TrophyWithEarned.tierEmoji('desconhecido'), '🏆');
    });

    test('tierLabel: concedido manual sem tier, a conquistar e tiers nomeados', () {
      final manual = TrophyWithEarned(
        trophyId: 'x',
        techniqueId: '',
        name: 'n',
        startDate: '2026-01-01',
        endDate: '2026-01-01',
        targetCount: 0,
        isManualAward: true,
      );
      expect(manual.tierLabel, 'Concedido');

      final pending = TrophyWithEarned(
        trophyId: 'x',
        techniqueId: 't',
        name: 'n',
        startDate: '2026-01-01',
        endDate: '2026-01-01',
        targetCount: 1,
      );
      expect(pending.tierLabel, 'A conquistar');

      final gold = TrophyWithEarned(
        trophyId: 'x',
        techniqueId: 't',
        name: 'n',
        startDate: '2026-01-01',
        endDate: '2026-01-01',
        targetCount: 1,
        earnedTier: 'gold',
      );
      expect(gold.tierLabel, 'Ouro');
    });

    test('graduationLabel traduz faixas e devolve original/nulo no fallback', () {
      expect(TrophyWithEarned.graduationLabel('white'), 'Branca');
      expect(TrophyWithEarned.graduationLabel('BLUE'), 'Azul');
      expect(TrophyWithEarned.graduationLabel('black'), 'Preta');
      expect(TrophyWithEarned.graduationLabel('coral'), 'coral');
      expect(TrophyWithEarned.graduationLabel(null), isNull);
      expect(TrophyWithEarned.graduationLabel(''), isNull);
    });
  });

  group('AcademyRecentItem helpers', () {
    AcademyRecentItem make(String name) => AcademyRecentItem.fromJson({
          'user_id': 'u',
          'user_name': name,
          'trophy_name': 'Troféu',
        });

    test('firstName e initials com nome composto', () {
      final item = make('João Silva Souza');
      expect(item.firstName, 'João');
      expect(item.initials, 'JS');
    });

    test('initials com nome único', () {
      expect(make('Madonna').initials, 'MA');
      expect(make('A').initials, 'A');
    });
  });
}
