import 'dart:async';

import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/training_video.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';
import 'package:viewer/widgets/youtube_player_embed.dart';

class TrainingVideoViewScreen extends StatefulWidget {
  final TrainingVideo video;

  const TrainingVideoViewScreen({super.key, required this.video});

  @override
  State<TrainingVideoViewScreen> createState() =>
      _TrainingVideoViewScreenState();
}

class _TrainingVideoViewScreenState extends State<TrainingVideoViewScreen> {
  final _api = ApiService();
  bool _watchedToEnd = false;
  bool _completing = false;
  bool _completedToday = false;
  String? _error;
  Timer? _durationTimer;

  TrainingVideo get _video => widget.video;

  @override
  void initState() {
    super.initState();
    _completedToday = _video.hasCompletedToday;
    _startFallbackTimerIfNeeded();
  }

  void _startFallbackTimerIfNeeded() {
    final durationSeconds = _video.durationSeconds;
    if (durationSeconds == null || durationSeconds <= 0) return;
    final millis = (durationSeconds * 1000 * 0.95).toInt();
    _durationTimer?.cancel();
    _durationTimer = Timer(Duration(milliseconds: millis), () {
      if (!mounted || _watchedToEnd) return;
      setState(() => _watchedToEnd = true);
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  Future<void> _onCompletePressed() async {
    setState(() {
      _completing = true;
      _error = null;
    });
    try {
      final res = await _api.completeTrainingVideo(_video.id);
      if (!mounted) return;
      final alreadyToday = res.alreadyCompletedToday;
      setState(() {
        _completing = false;
        _completedToday = res.hasCompletedToday || alreadyToday;
      });
      final baseMessage = alreadyToday
          ? 'Este vídeo já foi pontuado hoje. Tente novamente amanhã.'
          : (res.message ?? 'Pontos registrados com sucesso!');
      final points = res.pointsGranted ?? _video.pointsPerDay;
      final fullMessage =
          !alreadyToday ? '$baseMessage (+$points pts)' : baseMessage;
      AppFeedback.show(
        context,
        message: fullMessage,
        type: alreadyToday ? AppFeedbackType.info : AppFeedbackType.success,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _completing = false;
        _error = userFacingMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    final buttonEnabled = _watchedToEnd && !_completing && !_completedToday;
    final pointsLabel =
        '${v.pointsPerDay} ponto${v.pointsPerDay == 1 ? '' : 's'} por dia';

    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Campo de treinamento'),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              v.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimaryOf(context),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              pointsLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
            if (v.durationSeconds != null && v.durationSeconds! > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Duração aproximada: ~${(v.durationSeconds! ~/ 60).clamp(1, 999)} min',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
            ],
            const SizedBox(height: 16),
            YoutubePlayerEmbed(
              videoUrl: v.youtubeUrl,
              reelsMode: true,
              onEnded: () {
                if (!mounted) return;
                setState(() => _watchedToEnd = true);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Assista o vídeo até o fim para liberar os pontos de hoje.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: buttonEnabled ? _onCompletePressed : null,
              icon: _completing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _completedToday
                          ? Icons.check_circle
                          : Icons.sports_martial_arts,
                    ),
              label: Text(
                _completedToday
                    ? 'Concluído hoje'
                    : _watchedToEnd
                        ? 'Ganhar pontos de hoje'
                        : 'Assista até o fim para liberar',
              ),
              style: _completedToday
                  ? FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
