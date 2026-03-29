import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/screens/student/lesson_view_data.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';
import 'package:viewer/widgets/opponent_picker_sheet.dart';
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
  bool _pendingOpponentAcceptance = false;
  bool _reelsMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _alreadyCompleted = widget.data.alreadyCompleted;
    if (!_alreadyCompleted && widget.data.lessonId != null) {
      _fetchLessonCompletedStatus();
    }
    if ((widget.data.missionId != null || widget.data.lessonId != null) &&
        widget.data.academyId != null &&
        widget.data.academyId!.isNotEmpty) {
      _fetchPendingExecution();
    }
  }

  Future<void> _fetchPendingExecution() async {
    final missionId = widget.data.missionId;
    final lessonId = widget.data.lessonId;
    try {
      final list = await _api.getMyExecutions();
      final pending = list.any((e) {
        if ((e['status'] as String?) != 'pending_confirmation') return false;
        if (missionId != null && (e['mission_id'] as String?) == missionId) {
          return true;
        }
        if (lessonId != null && (e['lesson_id'] as String?) == lessonId) {
          return true;
        }
        return false;
      });
      if (mounted) setState(() => _pendingOpponentAcceptance = pending);
    } catch (_) {
      // Ignora; botão continua habilitado se não souber
    }
  }

  Future<void> _fetchLessonCompletedStatus() async {
    final lessonId = widget.data.lessonId;
    if (lessonId == null) return;
    try {
      final completed = await _api.getLessonCompleteStatus(lessonId: lessonId);
      if (mounted) setState(() => _alreadyCompleted = completed);
    } catch (_) {
      // Ignora erro; botão continua habilitado
    }
  }

  Future<void> _complete() async {
    final d = widget.data;
    if (d.missionId != null) {
      final usageTypeUi = await _showUsageTypeDialog();
      if (usageTypeUi == null || !mounted) return;
      final usageType = usageTypeUi == 'planned'
          ? 'after_training'
          : usageTypeUi == 'natural'
              ? 'before_training'
              : usageTypeUi;
      if (d.academyId != null && d.academyId!.isNotEmpty) {
        final opponentId = await _showOpponentDialog(d.academyId!);
        if (!mounted) return;
        if (opponentId != null && opponentId.isNotEmpty) {
          await _completeMissionWithOpponent(
              d.missionId!, usageType, opponentId);
        } else {
          await _completeMissionLegacy(d.missionId!, usageType);
        }
      } else {
        await _completeMissionLegacy(d.missionId!, usageType);
      }
    } else if (d.lessonId != null) {
      if (d.academyId != null && d.academyId!.isNotEmpty) {
        final usageTypeUi = await _showUsageTypeDialog();
        if (usageTypeUi == null || !mounted) return;
        final usageType = usageTypeUi == 'planned'
            ? 'after_training'
            : usageTypeUi == 'natural'
                ? 'before_training'
                : usageTypeUi;
        final opponentId = await _showOpponentDialog(d.academyId!);
        if (!mounted) return;
        if (opponentId != null && opponentId.isNotEmpty) {
          await _completeLessonWithOpponent(d.lessonId!, usageType, opponentId);
        } else {
          await _completeLesson(d.lessonId!);
        }
      } else {
        await _completeLesson(d.lessonId!);
      }
    } else {
      setState(() => _error = 'Nada a concluir');
      return;
    }
  }

  Future<String?> _showOpponentDialog(String academyId) {
    return OpponentPickerSheet.show(
      context,
      academyId: academyId,
      currentUserId: widget.data.userId,
      allowSkip: true,
    );
  }

  Future<void> _completeLessonWithOpponent(
      String lessonId, String usageType, String opponentId) async {
    setState(() {
      _completing = true;
      _error = null;
    });
    try {
      final res = await _api.postExecution(
        lessonId: lessonId,
        opponentId: opponentId,
        usageType: usageType,
      );
      if (!mounted) return;
      final message =
          res['message'] as String? ?? 'Aguardando confirmação do adversário.';
      AppFeedback.show(
        context,
        message: message,
        type: AppFeedbackType.info,
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

  Future<void> _completeMissionWithOpponent(
      String missionId, String usageType, String opponentId) async {
    setState(() {
      _completing = true;
      _error = null;
    });
    try {
      final res = await _api.postExecution(
        missionId: missionId,
        opponentId: opponentId,
        usageType: usageType,
      );
      if (!mounted) return;
      final message =
          res['message'] as String? ?? 'Aguardando confirmação do adversário.';
      AppFeedback.show(
        context,
        message: message,
        type: AppFeedbackType.info,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      if (_isMissionNotActiveError(e) && widget.data.lessonId != null) {
        await _completeLessonAsFallback();
        return;
      }
      setState(() {
        _completing = false;
        _error = userFacingMessage(e);
      });
    }
  }

  Future<void> _completeMissionLegacy(
      String missionId, String usageType) async {
    setState(() {
      _completing = true;
      _error = null;
    });
    try {
      await _api.postMissionComplete(
        missionId: missionId,
        usageType: usageType,
      );
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: 'Missão concluída!',
        type: AppFeedbackType.success,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      if (_isMissionNotActiveError(e) && widget.data.lessonId != null) {
        await _completeLessonAsFallback();
        return;
      }
      final msg = e.toString();
      final is409 = (e is ApiException && e.statusCode == 409) ||
          msg.toLowerCase().contains('já foi concluída');
      if (mounted) {
        setState(() {
          _completing = false;
          if (is409) _alreadyCompleted = true;
          _error = is409 ? null : userFacingMessage(e);
        });
      }
    }
  }

  bool _isMissionNotActiveError(dynamic e) {
    if (e is ApiException && e.statusCode == 400) {
      final m = e.message.toLowerCase();
      return m.contains('não está ativa') || m.contains('ativa no período');
    }
    return e.toString().toLowerCase().contains('não está ativa') ||
        e.toString().toLowerCase().contains('ativa no período');
  }

  Future<void> _completeLessonAsFallback() async {
    final lessonId = widget.data.lessonId;
    if (lessonId == null) return;
    try {
      await _api.postLessonComplete(lessonId: lessonId);
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: 'Missão fora do período; registrada como visualização da lição.',
        type: AppFeedbackType.info,
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

  Future<String?> _showUsageTypeDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PointerInterceptor(
        child: AlertDialog(
          content: const Text(
            'A execução foi premeditada focando no troféu/medalha ou posição do dia?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'planned'),
              child: const Text('Sim'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'natural'),
              child: const Text('Não, aconteceu naturalmente'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeLesson(String lessonId) async {
    setState(() {
      _completing = true;
      _error = null;
    });
    try {
      await _api.postLessonComplete(lessonId: lessonId);
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: 'Lição concluída!',
        type: AppFeedbackType.success,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final is409 = (e is ApiException && e.statusCode == 409) ||
          msg.toLowerCase().contains('já foi concluída');
      if (mounted) {
        setState(() {
          _completing = false;
          if (is409) _alreadyCompleted = true;
          _error = is409 ? null : userFacingMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Lição'),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
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
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 16),
              ),
            ],
            if (d.estimatedDurationSeconds != null &&
                d.estimatedDurationSeconds! > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Duração estimada: ~${d.estimatedDurationSeconds! ~/ 60} min',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            YoutubePlayerEmbed(
                videoUrl: d.videoUrl.isNotEmpty ? d.videoUrl : null,
                reelsMode: _reelsMode),
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
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textPrimary),
              ),
            if (d.description.isNotEmpty) const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              const SizedBox(height: 12),
            ],
            if (widget.data.missionId != null || widget.data.lessonId != null)
              FilledButton.icon(
                onPressed: _alreadyCompleted ||
                        _completing ||
                        _pendingOpponentAcceptance
                    ? null
                    : _complete,
                icon: _alreadyCompleted
                    ? const Icon(Icons.check_circle)
                    : _pendingOpponentAcceptance
                        ? const Icon(Icons.schedule)
                        : _completing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle),
                label: Text(
                  _alreadyCompleted
                      ? (widget.data.missionId != null
                          ? 'Missão concluída'
                          : 'Lição concluída')
                      : _pendingOpponentAcceptance
                          ? 'Aguardando aceite do oponente'
                          : _completing
                              ? 'Registrando...'
                              : 'Concluir',
                ),
                style: _alreadyCompleted
                    ? FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700)
                    : _pendingOpponentAcceptance
                        ? FilledButton.styleFrom(backgroundColor: Colors.grey)
                        : null,
              ),
          ],
        ),
      ),
    );
  }
}
