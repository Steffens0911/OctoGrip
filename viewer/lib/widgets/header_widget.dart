import 'package:flutter/material.dart';
import 'package:viewer/theme/fantasy_theme.dart';

/// Header da home fantasia: saudação, brasão da academia, nome, barra XP e badge da tarefa diária.
class HeaderWidget extends StatelessWidget {
  const HeaderWidget({
    super.key,
    this.userName = 'Perin',
    this.userBelt = 'Preta',
    this.currentXp = 0,
    this.maxXp = 519,
    this.academyLogoUrl,
    this.dailyVideoPoints = 30,
    this.dailyVideoCompleted = false,
    this.onDailyVideoTap,
  });

  final String userName;
  final String userBelt;
  final int currentXp;
  final int maxXp;
  /// URL do brasão da academia (exibido no círculo central).
  final String? academyLogoUrl;
  /// Pontos do vídeo diário que pontua; exibido no badge.
  final int dailyVideoPoints;
  /// Se true, badge mostra "Tarefa concluída · Ver de novo" (ainda clicável para assistir sem pontuar).
  final bool dailyVideoCompleted;
  final VoidCallback? onDailyVideoTap;

  @override
  Widget build(BuildContext context) {
    final progress = maxXp > 0 ? (currentXp / maxXp).clamp(0.0, 1.0) : 0.0;
    final displayName = userBelt.isNotEmpty ? '$userName — $userBelt' : userName;
    final showBadge = dailyVideoPoints > 0 || dailyVideoCompleted;
    final badgeLabel = dailyVideoCompleted
        ? 'Tarefa concluída · Ver de novo'
        : '+ $dailyVideoPoints XP Completar tarefa!';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Olá, $userName!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: FantasyTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aqui estão suas missões e atividades da semana',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: FantasyTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 44,
                backgroundColor: FantasyTheme.gold,
                child: CircleAvatar(
                  radius: 41,
                  backgroundColor: FantasyTheme.cardSurfaceTop,
                  backgroundImage: academyLogoUrl != null &&
                          academyLogoUrl!.isNotEmpty
                      ? NetworkImage(academyLogoUrl!)
                      : null,
                  child: academyLogoUrl == null || academyLogoUrl!.isEmpty
                      ? const Icon(
                          Icons.shield_outlined,
                          size: 40,
                          color: FantasyTheme.textSecondary,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: FantasyTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: FantasyTheme.cardSurfaceTop,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: FantasyTheme.textMuted.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 28,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            FantasyTheme.xpGreen,
                          ),
                          minHeight: 28,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 28),
                      child: Text(
                        '$currentXp / $maxXp XP',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: FantasyTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                    const Positioned(
                      right: 8,
                      child: Icon(
                        Icons.workspace_premium,
                        size: 20,
                        color: FantasyTheme.gold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showBadge)
            Positioned(
              top: -4,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDailyVideoTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Opacity(
                    opacity: dailyVideoCompleted ? 0.85 : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: FantasyTheme.cardSurfaceTop.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: dailyVideoCompleted
                              ? FantasyTheme.textMuted.withValues(alpha: 0.5)
                              : FantasyTheme.xpGreen.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        badgeLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: dailyVideoCompleted
                                  ? FantasyTheme.textSecondary
                                  : FantasyTheme.xpGreen,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
