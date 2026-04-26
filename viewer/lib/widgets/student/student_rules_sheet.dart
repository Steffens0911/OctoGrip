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
                'Resumo rápido para evitar dúvidas e garantir registros justos.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryOf(ctx),
                ),
              ),
              const SizedBox(height: 16),
              const _RuleBlock(
                title: 'Regra nº 1 (antes do rola)',
                body:
                    'Antes de começar, combine com seu parceiro se aquele rola vai ser registrado no app. '
                    'Assim ninguém é pego de surpresa com solicitações/confirmações depois.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Adversário é obrigatório',
                body:
                    'Nenhuma conclusão pode ser registrada sem adversário. Selecione um colega para registrar.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Limite diário por adversário',
                body:
                    'Você só pode registrar 1 execução por dia para o mesmo adversário. Se já registrou hoje, tente amanhã.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Confirmações',
                body:
                    'Quando você registra, o adversário precisa confirmar (ou recusar). '
                    'Quando alguém te indica como adversário, responda as confirmações pendentes.',
              ),
              const SizedBox(height: 18),
              Text(
                'Critérios técnicos (qualidade do registro)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const _RuleBlock(
                title: 'Finalizações',
                body:
                    'Não precisam terminar em “tap”. Para contar, precisam gerar perigo real (controle + ameaça clara). '
                    'Não force a finalização só para “contar”.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Raspagens',
                body:
                    'Para contar, precisam gerar perigo real de raspagem (desequilíbrio, controle de base e progressão).',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Defesas',
                body: 'Para contar, precisam ser executadas com sucesso.',
              ),
              const SizedBox(height: 12),
              const _RuleBlock(
                title: 'Transições',
                body:
                    'Para contar, precisam ser completas e estabilizadas (ex.: costas, montada, joelho na barriga, 100kg).',
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

