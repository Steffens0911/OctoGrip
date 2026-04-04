/// Bottom sheet “Como funcionam os pontos” na home do aluno.
///
/// Valores de bónus de sequência: `gamification_constants.dart`.
library;
import 'package:flutter/material.dart';

import 'package:viewer/core/gamification_constants.dart';

/// Abre um bottom sheet com as regras de pontuação (aluno).
void showPointsRulesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Como funcionam os pontos',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const _RuleBlock(
                title: 'Total de pontos e nível',
                body:
                    'Os pontos somam missões, lições, execuções confirmadas por parceiros, '
                    'ajustes da academia e, quando aplicável, o vídeo da tarefa diária. '
                    'A barra no topo mostra o progresso até ao próximo nível.',
              ),
              const SizedBox(height: 14),
              const _RuleBlock(
                title: 'Tarefa diária',
                body:
                    'Ao completar o vídeo diário pela primeira vez no dia, ganha os pontos '
                    '(XP) indicados no selo por baixo do brasão.',
              ),
              const SizedBox(height: 14),
              const _RuleBlock(
                title: 'Sequência de login',
                body:
                    'Conta um dia por calendário em UTC em que entra na app. '
                    'Se falhar um dia UTC, a sequência volta a zero.',
              ),
              const SizedBox(height: 14),
              const _RuleBlock(
                title: 'Bónus de sequência',
                body:
                    'A cada $kLoginStreakBonusIntervalDays dias consecutivos de login '
                    '($kLoginStreakBonusIntervalDays, ${kLoginStreakBonusIntervalDays * 2}, …), '
                    'ao fazer login nesse dia recebe +$kLoginStreakBonusPoints pontos extra.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _RuleBlock extends StatelessWidget {
  const _RuleBlock({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.35,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
