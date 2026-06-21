import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/training_session.dart';
import 'package:viewer/screens/academy/attendance_session_screen.dart';
import 'package:viewer/screens/academy/launch_training_screen.dart';
import 'package:viewer/screens/academy/training_session_summary_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Lista de treinos lançados pelo professor — card com status, abrir/fechar/excluir.
class TrainingSessionListScreen extends StatefulWidget {
  final String academyId;

  const TrainingSessionListScreen({super.key, required this.academyId});

  @override
  State<TrainingSessionListScreen> createState() => _TrainingSessionListScreenState();
}

class _TrainingSessionListScreenState extends State<TrainingSessionListScreen> {
  final ApiService _api = ApiService();
  List<TrainingSession> _sessions = [];
  bool _loading = true;
  String? _error;

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
      final raw = await _api.getTrainingSessions(widget.academyId, limit: 100);
      if (!mounted) return;
      setState(() {
        _sessions = raw.map(TrainingSession.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _open(TrainingSession s) async {
    // Abre a chamada via API e navega para a tela de presença vinculada ao treino.
    try {
      final updated = await _api.openTrainingSession(s.id);
      _replaceSession(TrainingSession.fromJson(updated));
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttendanceSessionScreen(
            trainingSessionId: s.id,
          ),
        ),
      );
      // Recarrega ao voltar (presença pode ter mudado)
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _close(TrainingSession s) async {
    try {
      final updated = await _api.closeTrainingSession(s.id);
      _replaceSession(TrainingSession.fromJson(updated));
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _delete(TrainingSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir treino?'),
        content: Text('Excluir "${s.displayName}" de ${s.classDate}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteTrainingSession(s.id);
      setState(() => _sessions.removeWhere((t) => t.id == s.id));
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  void _replaceSession(TrainingSession updated) {
    if (!mounted) return;
    setState(() {
      final idx = _sessions.indexWhere((s) => s.id == updated.id);
      if (idx >= 0) _sessions[idx] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Treinos lançados'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final launched = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => LaunchTrainingScreen(
                academyId: widget.academyId,
                onLaunched: _load,
              ),
            ),
          );
          if (launched == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Lançar treino'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _sessions.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_martial_arts, size: 64, color: AppTheme.textMutedOf(context)),
          const SizedBox(height: 12),
          Text(
            'Nenhum treino lançado ainda.',
            style: TextStyle(color: AppTheme.textSecondaryOf(context)),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque em "Lançar treino" para começar.',
            style: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // Agrupar por data
    final Map<String, List<TrainingSession>> byDate = {};
    for (final s in _sessions) {
      (byDate[s.classDate] ??= []).add(s);
    }
    final dates = byDate.keys.toList()..sort();

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        AppTheme.screenPadding(context),
        AppTheme.screenPadding(context),
        AppTheme.screenPadding(context),
        100,
      ),
      itemCount: dates.length,
      itemBuilder: (context, i) {
        final day = dates[i];
        final daySessions = byDate[day]!;
        final parts = day.split('-');
        final label =
            '${parts[2]}/${parts[1]}/${parts[0]}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 12),
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...daySessions.map((s) => _SessionCard(
                  session: s,
                  onOpen: () => _open(s),
                  onClose: () => _close(s),
                  onDelete: () => _delete(s),
                  onSummary: s.isClosed && s.preCheckinCount > 0
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrainingSessionSummaryScreen(
                                sessionId: s.id,
                                sessionName: s.displayName,
                              ),
                            ),
                          )
                      : null,
                )),
          ],
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  final TrainingSession session;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback? onSummary;

  const _SessionCard({
    required this.session,
    required this.onOpen,
    required this.onClose,
    required this.onDelete,
    this.onSummary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.displayName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                _StatusChip(status: session.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tolerância: ${session.toleranceMinutes} min',
              style: TextStyle(
                color: AppTheme.textSecondaryOf(context),
                fontSize: 13,
              ),
            ),
            if (session.preCheckinCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${session.preCheckinCount} confirmado(s)',
                style: const TextStyle(fontSize: 13, color: Color(0xFF1D9E75)),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (session.isUpcoming)
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Abrir chamada'),
                  ),
                if (session.isOpen)
                  FilledButton.icon(
                    onPressed: onClose,
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('Encerrar'),
                  ),
                if (onSummary != null)
                  OutlinedButton.icon(
                    onPressed: onSummary,
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('Ver resumo'),
                  ),
                if (!session.isOpen)
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    label: Text(
                      'Excluir',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    String label;
    switch (status) {
      case 'open':
        bg = const Color(0xFF1D9E75);
        label = 'aberto';
      case 'closed':
        bg = Colors.grey;
        label = 'encerrado';
      default:
        bg = const Color(0xFF378ADD);
        label = 'agendado';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: bg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
