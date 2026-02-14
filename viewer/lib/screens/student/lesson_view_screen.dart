import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/screens/student/lesson_view_data.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/widgets/youtube_player_embed.dart';

/// Tela de visualização de uma lição (missão do dia ou biblioteca). Botão Concluir registra no backend.
class LessonViewScreen extends StatefulWidget {
  final LessonViewData data;

  const LessonViewScreen({super.key, required this.data});

  @override
  State<LessonViewScreen> createState() => _LessonViewScreenState();
}

class _LessonViewScreenState extends State<LessonViewScreen> {
  final _api = ApiService();
  bool _completing = false;
  bool _alreadyCompleted = false;
  bool _reelsMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _alreadyCompleted = widget.data.alreadyCompleted;
    if (!_alreadyCompleted &&
        widget.data.lessonId != null &&
        widget.data.missionId == null) {
      _fetchLessonCompletedStatus();
    }
  }

  Future<void> _fetchLessonCompletedStatus() async {
    final lessonId = widget.data.lessonId;
    if (lessonId == null) return;
    try {
      final completed = await _api.getLessonCompleteStatus(
        userId: widget.data.userId,
        lessonId: lessonId,
      );
      if (mounted) setState(() => _alreadyCompleted = completed);
    } catch (_) {
      // Ignora erro; botão continua habilitado
    }
  }

  Future<void> _complete() async {
    final d = widget.data;
    if (d.missionId != null) {
      final usageType = await _showUsageTypeDialog();
      if (usageType != null && mounted) await _completeMission(d.missionId!, usageType);
    } else if (d.lessonId != null) {
      await _completeLesson(d.lessonId!);
    } else {
      setState(() => _error = 'Nada a concluir');
      return;
    }
  }

  Future<String?> _showUsageTypeDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PointerInterceptor(
        child: AlertDialog(
          title: const Text('Quando você visualizou?'),
          content: const Text(
            'Em que momento você assistiu ou revisou esta técnica?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'before_training'),
              child: const Text('Antes do treino'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'after_training'),
              child: const Text('Depois do treino'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeMission(String missionId, String usageType) async {
    setState(() {
      _completing = true;
      _error = null;
    });
    try {
      await _api.postMissionComplete(
        userId: widget.data.userId,
        missionId: missionId,
        usageType: usageType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missão concluída!'), backgroundColor: AppTheme.primary),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final is409 = (e is ApiException && e.statusCode == 409) ||
          msg.toLowerCase().contains('já foi concluída');
      setState(() {
        _completing = false;
        if (is409) _alreadyCompleted = true;
        _error = is409 ? null : msg;
      });
    }
  }

  Future<void> _completeLesson(String lessonId) async {
    setState(() {
      _completing = true;
      _error = null;
    });
    try {
      await _api.postLessonComplete(
        userId: widget.data.userId,
        lessonId: lessonId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lição concluída!'), backgroundColor: AppTheme.primary),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final is409 = (e is ApiException && e.statusCode == 409) ||
          msg.toLowerCase().contains('já foi concluída');
      setState(() {
        _completing = false;
        if (is409) _alreadyCompleted = true;
        _error = is409 ? null : msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Scaffold(
      appBar: AppBar(title: const Text('Lição')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              d.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (d.techniqueName != null && d.techniqueName!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                d.positionName != null && d.positionName!.isNotEmpty
                    ? '${d.techniqueName!} ${d.positionName}'
                    : d.techniqueName!,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
            ],
            if (d.estimatedDurationSeconds != null && d.estimatedDurationSeconds! > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Duração estimada: ~${d.estimatedDurationSeconds! ~/ 60} min',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            YoutubePlayerEmbed(videoUrl: d.videoUrl.isNotEmpty ? d.videoUrl : null, reelsMode: _reelsMode),
            const SizedBox(height: 12),
            Row(
              children: [
                FilterChip(
                  label: const Text('Modo Reels'),
                  selected: _reelsMode,
                  onSelected: (v) => setState(() => _reelsMode = v),
                  selectedColor: AppTheme.primary.withValues(alpha: 0.3),
                  checkmarkColor: AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (d.description.isNotEmpty)
              Text(
                d.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
              ),
            if (d.description.isNotEmpty) const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              const SizedBox(height: 12),
            ],
            if (widget.data.missionId != null || widget.data.lessonId != null)
              FilledButton.icon(
                onPressed: _alreadyCompleted || _completing ? null : _complete,
                icon: _alreadyCompleted
                    ? const Icon(Icons.check_circle)
                    : _completing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle),
                label: Text(
                  _alreadyCompleted
                      ? (widget.data.missionId != null ? 'Missão concluída' : 'Lição concluída')
                      : _completing
                          ? 'Registrando...'
                          : 'Concluir',
                ),
                style: _alreadyCompleted
                    ? FilledButton.styleFrom(backgroundColor: Colors.green.shade700)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
