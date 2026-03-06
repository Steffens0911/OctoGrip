import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/training_video.dart';
import 'package:viewer/screens/student/training_video_view_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';

class TrainingVideosSection extends StatefulWidget {
  const TrainingVideosSection({super.key});

  @override
  State<TrainingVideosSection> createState() => _TrainingVideosSectionState();
}

class _TrainingVideosSectionState extends State<TrainingVideosSection> {
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
      setState(() {
        _videos = list;
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Carregando campo de treinamento...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _error!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _load,
                child: const Text('Tentar novamente'),
              ),
            ),
          ],
        ),
      );
    }

    final currentUser = AuthService().currentUser;
    final userAcademyId = currentUser?.academyId;
    final localVideos = _videos.where((v) {
      if (userAcademyId == null || userAcademyId.isEmpty) {
        return false;
      }
      return v.academyId == userAcademyId;
    }).toList();

    if (localVideos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          userAcademyId == null || userAcademyId.isEmpty
              ? 'Nenhum vídeo de campo de treinamento disponível. Vincule-se a uma academia para ver vídeos locais.'
              : 'Nenhum vídeo de campo de treinamento disponível hoje para sua academia.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryOf(context),
              ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var v in localVideos) ...[
          _TrainingVideoTile(
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
    );
  }
}

class _TrainingVideoTile extends StatelessWidget {
  final TrainingVideo video;
  final VoidCallback onOpen;

  const _TrainingVideoTile({
    required this.video,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final completedToday = video.hasCompletedToday;
    final pointsLabel = '${video.pointsPerDay} ponto${video.pointsPerDay == 1 ? '' : 's'} por dia';
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            completedToday ? Icons.check_circle : Icons.play_circle_fill,
            color: completedToday ? Colors.green.shade700 : AppTheme.primary,
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

