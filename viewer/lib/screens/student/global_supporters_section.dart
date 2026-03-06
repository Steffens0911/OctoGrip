import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/training_video.dart';
import 'package:viewer/screens/student/training_video_view_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

class GlobalSupportersSection extends StatefulWidget {
  const GlobalSupportersSection({super.key});

  @override
  State<GlobalSupportersSection> createState() =>
      _GlobalSupportersSectionState();
}

class _GlobalSupportersSectionState extends State<GlobalSupportersSection> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<TrainingVideo> _videos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getTrainingVideosToday();
      if (!mounted) return;
      _videos = list.where((v) => v.academyId == null).toList();
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }
    if (_error != null || _videos.isEmpty) {
      // Se não houver vídeos globais ou houver erro, não exibe a seção.
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.favorite_outline,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Apoiadores do app',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textPrimaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Conteúdos especiais oferecidos por apoiadores do aplicativo.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
              const SizedBox(height: 12),
              for (final v in _videos) ...[
                _GlobalSupporterTile(
                  video: v,
                  onOpen: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrainingVideoViewScreen(video: v),
                      ),
                    );
                    if (!mounted) return;
                    _load();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GlobalSupporterTile extends StatelessWidget {
  final TrainingVideo video;
  final VoidCallback onOpen;

  const _GlobalSupporterTile({
    required this.video,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final completedToday = video.hasCompletedToday;
    final pointsLabel =
        '${video.pointsPerDay} ponto${video.pointsPerDay == 1 ? '' : 's'} por dia';
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.ondemand_video_rounded,
            color: AppTheme.primary,
          ),
        ),
        title: Text(
          video.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.textPrimaryOf(context),
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              pointsLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
            if (completedToday) ...[
              const SizedBox(height: 2),
              Text(
                'Concluído hoje · volte amanhã para pontuar de novo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green.shade700,
                    ),
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: AppTheme.textMutedOf(context),
        ),
        onTap: onOpen,
      ),
    );
  }
}

