import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';

/// Bottom sheet: regras gerais do aluno (resumo dentro do app).
void showStudentRulesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final bottomInset = MediaQuery.paddingOf(ctx).bottom;
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Regras do aluno',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para evitar dúvidas e garantir registros justos.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryOf(ctx),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionTitle(title: 'Regras'),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Regra nº 1 (antes do rola)',
                body:
                    'Antes de começar, combine com seu parceiro se aquele rola vai ser registrado no app. '
                    'Assim ninguém é pego de surpresa com solicitações/confirmações depois.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Adversário é obrigatório',
                body:
                    'Nenhuma conclusão/registro pode ser feito sem adversário. Selecione um colega para registrar.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Confirmações',
                body:
                    'Ao registrar uma execução, ela fica pendente até o adversário confirmar (ou recusar). '
                    'Se você for indicado como adversário, responda as confirmações pendentes.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Limite diário por adversário (global)',
                body:
                    'Você só pode registrar 1 execução por dia para o mesmo adversário, independentemente do tipo.',
              ),
              const SizedBox(height: 18),
              const _SectionTitle(title: 'Critérios técnicos (regras do registro)'),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Finalizações',
                body:
                    'Não precisam terminar em “tap”. Para registrar, precisam gerar perigo real (controle + ameaça clara). '
                    'Não force a finalização só para “contar”.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Raspagens',
                body:
                    'Para registrar, devem ao menos gerar perigo real de raspagem (desequilíbrio, controle de base e progressão).',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Defesas',
                body:
                    'Para registrar, devem ser executadas com sucesso (defesa efetiva, resultado claro).',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Transições',
                body:
                    'Para registrar, devem ser completas e com a devida estabilização (costas, montada, joelho na barriga, 100kg, etc.).',
              ),
              const SizedBox(height: 18),
              const _SectionTitle(title: 'Orientações'),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Pontos / XP / Nível',
                body:
                    'Seus pontos somam missões, lições, execuções confirmadas, ajustes da academia e, quando aplicável, o vídeo da tarefa diária. '
                    'A barra no topo mostra o progresso até o próximo nível.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Tarefa diária (vídeo)',
                body:
                    'Para liberar os pontos do dia, assista o vídeo até o fim. O vídeo pontua apenas uma vez por dia.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Sequência de login',
                body:
                    'Conta 1 dia por calendário (horário de Brasília) em que você entra no app. Se perder um dia, a sequência zera. '
                    'A cada 7 dias seguidos, você ganha +50 pontos de bônus.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Missões e lições',
                body:
                    'Missões só podem ser registradas quando estiverem ativas no período. Se uma missão já foi concluída, ela não deve ser registrada novamente.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Troféus / medalhas',
                body:
                    'Algumas premiações ficam trancadas até atingir nível mínimo e/ou faixa mínima. A academia pode configurar limites por adversário no período e sua galeria pode ser visível ou privada.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Vínculo com academia',
                body:
                    'Para usar algumas funções (parceiros, horários, frequência e registro com adversário), seu usuário precisa estar vinculado a uma academia.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Presença (chamada por QR)',
                body:
                    'A presença é registrada escaneando (ou colando) o código do QR exibido pelo professor; a confirmação depende da validação da API.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Conta congelada',
                body:
                    'Se a conta estiver congelada, você fica em modo de restrição até regularizar com a academia.',
              ),
              const SizedBox(height: 22),
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
  const _RuleBlock({required this.title, required this.body});

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
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          color: theme.dividerColor.withValues(alpha: 0.35),
        ),
      ],
    );
  }
}

