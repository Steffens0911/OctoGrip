import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:viewer/core/leveling.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/theme/fantasy_theme.dart';

/// Header da home fantasia: saudação, brasão da academia, faixa (sob o brasão), barra XP e badge da tarefa diária.
class HeaderWidget extends StatelessWidget {
  const HeaderWidget({
    super.key,
    this.userName = 'Perin',
    this.userBelt = 'Preta',
    this.userLevel = 1,
    this.currentXp = 0,
    this.maxXp = kBaseLevelThreshold,
    this.userAvatarUrl,
    this.academyLogoUrl,
    this.academyName,
    this.dailyVideoPoints = 30,
    this.dailyVideoCompleted = false,
    this.onDailyVideoTap,
    this.onOpenRules,
    this.onOpenTour,
    this.onAvatarTap,
  });

  final String userName;
  final String userBelt;
  final int userLevel;
  final int currentXp;
  final int maxXp;
  /// URL da foto de perfil do aluno (exibida no círculo central).
  final String? userAvatarUrl;
  /// URL do brasão da academia (mantido para uso futuro / admin).
  final String? academyLogoUrl;
  /// Nome da academia exibido abaixo da faixa.
  final String? academyName;
  /// Pontos do vídeo diário que pontua; exibido no badge.
  final int dailyVideoPoints;
  /// Se true, badge mostra "Tarefa concluída · Ver de novo" (ainda clicável para assistir sem pontuar).
  final bool dailyVideoCompleted;
  final VoidCallback? onDailyVideoTap;
  final VoidCallback? onOpenRules;
  /// Abre o tour de primeiro acesso do Campo de Treinamento.
  final VoidCallback? onOpenTour;
  /// Chamado ao tocar na foto de perfil para permitir troca.
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final progress = maxXp > 0 ? (currentXp / maxXp).clamp(0.0, 1.0) : 0.0;
    final beltUnderCrest = userBelt.isNotEmpty
        ? 'Faixa $userBelt'
        : 'Faixa —';
    final showBadge = dailyVideoPoints > 0 || dailyVideoCompleted;
    final badgeLabel = dailyVideoCompleted
        ? 'Tarefa concluída · Revisar fortalece sua técnica'
        : '+ $dailyVideoPoints XP · Complete a tarefa diária';

    final screenW = MediaQuery.sizeOf(context).width;
    final badgeMaxW = (screenW - 32).clamp(160.0, 280.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Olá, $userName!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: FantasyTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              if (onOpenTour != null)
                IconButton(
                  onPressed: onOpenTour,
                  icon: const Icon(Icons.help_outline_rounded, size: 20),
                  color: FantasyTheme.textSecondaryOf(context),
                  tooltip: 'Como funciona',
                ),
              if (onOpenRules != null)
                TextButton.icon(
                  onPressed: onOpenRules,
                  icon: const Icon(Icons.rule_rounded, size: 18),
                  label: const Text('Regras'),
                  style: TextButton.styleFrom(
                    foregroundColor: FantasyTheme.textSecondaryOf(context),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          AppSpacing.verticalS,
          Text(
            'Construa consistência e evolua sua técnica esta semana',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FantasyTheme.textSecondaryOf(context),
                ),
          ),
          if (showBadge) ...[
            AppSpacing.verticalM,
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: badgeMaxW),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onDailyVideoTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Opacity(
                      opacity: dailyVideoCompleted ? 0.85 : 1.0,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: FantasyTheme.insetSurfaceOf(context)
                              .withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: dailyVideoCompleted
                                ? FantasyTheme.textMutedOf(context)
                                    .withValues(alpha: 0.5)
                                : FantasyTheme.xpGreenOf(context)
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          badgeLabel,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: dailyVideoCompleted
                                        ? FantasyTheme.textSecondaryOf(context)
                                        : FantasyTheme.xpGreenOf(context),
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          AppSpacing.verticalM,
          Semantics(
            label: 'Foto de perfil — toque para alterar',
            button: true,
            child: Center(
              child: GestureDetector(
                onTap: onAvatarTap,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: FantasyTheme.accentOf(context),
                      child: CircleAvatar(
                        radius: 41,
                        backgroundColor: FantasyTheme.insetSurfaceOf(context),
                        child: userAvatarUrl != null && userAvatarUrl!.isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: userAvatarUrl!,
                                  width: 82,
                                  height: 82,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Icon(Icons.person, size: 40),
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.person, size: 40),
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 40,
                                color: FantasyTheme.textSecondaryOf(context),
                              ),
                      ),
                    ),
                    if (onAvatarTap != null)
                      Container(
                        decoration: BoxDecoration(
                          color: FantasyTheme.accentOf(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: FantasyTheme.insetSurfaceOf(context),
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
          ),
          AppSpacing.verticalS,
          Text(
            beltUnderCrest,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: FantasyTheme.textPrimaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (academyName != null && academyName!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              academyName!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FantasyTheme.textSecondaryOf(context),
                  ),
            ),
          ],
          AppSpacing.verticalS,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: FantasyTheme.insetSurfaceOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: FantasyTheme.textMutedOf(context)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                ),
                Semantics(
                  label: 'Progresso de experiência',
                  value: 'Level $userLevel, $currentXp de $maxXp XP',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 28,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          FantasyTheme.xpGreenOf(context),
                        ),
                        minHeight: 28,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 28),
                  child: Text(
                    'Level $userLevel · $currentXp / $maxXp XP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: FantasyTheme.textPrimaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Positioned(
                  right: 8,
                  child: Icon(
                    Icons.workspace_premium,
                    size: 20,
                    color: FantasyTheme.accentOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
