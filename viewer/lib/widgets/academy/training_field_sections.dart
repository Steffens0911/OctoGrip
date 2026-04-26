import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/design/app_tokens.dart';

class AcademyTrainingFieldSections extends StatelessWidget {
  const AcademyTrainingFieldSections({
    super.key,
    required this.onOpenTechniques,
    required this.onOpenTrophies,
    required this.hasActiveTurmas,
    required this.onWeeklyKitsExpansionChanged,
    required this.weeklyKitsChildren,
    required this.weeklyMissionsChildren,
  });

  final Future<void> Function() onOpenTechniques;
  final VoidCallback onOpenTrophies;
  final bool hasActiveTurmas;
  final ValueChanged<bool> onWeeklyKitsExpansionChanged;
  final List<Widget> weeklyKitsChildren;
  final List<Widget> weeklyMissionsChildren;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Card(
            child: ExpansionTile(
              title: Text(
                'Posições e técnicas',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              initiallyExpanded: false,
              controlAffinity: ListTileControlAffinity.leading,
              childrenPadding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.alt_route_rounded),
                  title: const Text(
                    'Técnicas (para serem vinculadas aos troféus e posições da semana)',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async => onOpenTechniques(),
                ),
              ],
            ),
          ),
        ),
        AppSpacing.verticalM,
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Card(
            child: ExpansionTile(
              title: Text(
                'Troféus e missões semanais',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              initiallyExpanded: false,
              controlAffinity: ListTileControlAffinity.leading,
              childrenPadding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: const Text('Troféus'),
                  subtitle: const Text('Gerencie os troféus desta academia'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenTrophies,
                ),
                const Divider(height: 1),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: const Text('Turmas (semana)'),
                    subtitle: const Text(
                      '1 a 5 técnicas por turma; o aluno escolhe a turma por semana.',
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    initiallyExpanded: false,
                    controlAffinity: ListTileControlAffinity.leading,
                    onExpansionChanged: onWeeklyKitsExpansionChanged,
                    children: weeklyKitsChildren,
                  ),
                ),
                const Divider(height: 1),
                if (hasActiveTurmas)
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Missões fixas (3 técnicas)'),
                    subtitle: Text(
                      'Ocultas: esta academia usa só turmas. Para voltar ao modo de três missões fixas, '
                      'remova ou deixe sem técnicas válidas todas as turmas.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  )
                else
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: const Text('Missões semanais (legado)'),
                      childrenPadding: const EdgeInsets.all(16),
                      initiallyExpanded: false,
                      controlAffinity: ListTileControlAffinity.leading,
                      children: weeklyMissionsChildren,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
