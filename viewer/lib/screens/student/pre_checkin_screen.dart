import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/pre_checkin.dart';
import 'package:viewer/models/training_session.dart';
import 'package:viewer/models/training_stats.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';
import 'package:viewer/widgets/student/student_hankins_section.dart';

/// Tela do aluno: lista treinos agendados e permite confirmar/cancelar presença.
///
/// Quando [date] é fornecido (formato YYYY-MM-DD), exibe apenas as sessões
/// daquele dia (link compartilhado pelo professor).
class PreCheckinScreen extends StatefulWidget {
  final String academyId;
  final String? date;

  const PreCheckinScreen({super.key, required this.academyId, this.date});

  @override
  State<PreCheckinScreen> createState() => _PreCheckinScreenState();
}

class _PreCheckinScreenState extends State<PreCheckinScreen> {
  final ApiService _api = ApiService();
  List<TrainingSession> _sessions = [];
  TrainingStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PreCheckinScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.academyId != widget.academyId || oldWidget.date != widget.date) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessionsFuture = _api.getTrainingSessions(
        widget.academyId,
        classDate: widget.date,
        status: widget.date == null ? 'upcoming' : null,
        limit: 50,
      );
      Future<TrainingStats?> statsFuture() async {
        try {
          return await _api.getTrainingStats();
        } catch (_) {
          return null;
        }
      }

      final results = await Future.wait([sessionsFuture, statsFuture()]);
      if (!mounted) return;
      setState(() {
        _sessions = (results[0] as List).map((e) => TrainingSession.fromJson(e as Map<String, dynamic>)).toList();
        _stats = results[1] as TrainingStats?;
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

  String _appBarTitle() {
    final d = widget.date;
    if (d == null) return 'Confirmar presença';
    final parts = d.split('-');
    if (parts.length == 3) return 'Treinos de ${parts[2]}/${parts[1]}/${parts[0]}';
    return 'Confirmar presença';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppStandardAppBar(title: _appBarTitle()),
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
            widget.date != null
                ? 'Nenhum treino encontrado para este dia.'
                : 'Nenhum treino agendado por enquanto.',
            style: TextStyle(color: AppTheme.textSecondaryOf(context)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.date != null
                ? 'O professor ainda não lançou treinos para esta data.'
                : 'Quando o professor lançar um treino ele aparece aqui.',
            style: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final Map<String, List<TrainingSession>> byDate = {};
    for (final s in _sessions) {
      (byDate[s.classDate] ??= []).add(s);
    }
    final dates = byDate.keys.toList()..sort();
    final pad = AppTheme.screenPadding(context);

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
      itemCount: dates.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _stats != null
              ? StudentHankinsSection(stats: _stats!)
              : const SizedBox.shrink();
        }
        final day = dates[i - 1];
        final daySessions = byDate[day]!;
        final parts = day.split('-');
        final label = '${parts[2]}/${parts[1]}/${parts[0]}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 1) const SizedBox(height: 16),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...daySessions.map((s) => _SessionCheckinCard(
                  session: s,
                  onRefresh: _load,
                )),
          ],
        );
      },
    );
  }
}

class _SessionCheckinCard extends StatefulWidget {
  final TrainingSession session;
  final VoidCallback onRefresh;

  const _SessionCheckinCard({required this.session, required this.onRefresh});

  @override
  State<_SessionCheckinCard> createState() => _SessionCheckinCardState();
}

class _SessionCheckinCardState extends State<_SessionCheckinCard> {
  final ApiService _api = ApiService();
  PreCheckinStatus? _status;
  bool _loadingStatus = true;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final raw = await _api.getPreCheckinStatus(widget.session.id);
      if (mounted) {
        setState(() {
          _status = PreCheckinStatus.fromJson(raw);
          _loadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _confirm() async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await _api.confirmPreCheckin(widget.session.id);
      await _loadStatus();
      if (mounted) {
        AppFeedback.show(context, message: 'Presença confirmada!', type: AppFeedbackType.success);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _cancel() async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await _api.cancelPreCheckin(widget.session.id);
      await _loadStatus();
      if (mounted) {
        AppFeedback.show(context, message: 'Confirmação cancelada.', type: AppFeedbackType.info);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _showConfirmants() {
    final s = _status;
    if (s == null || s.confirmants.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ConfirmantsSheet(
        sessionName: widget.session.displayName,
        confirmants: s.confirmants,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final isConfirmed = s?.isConfirmed ?? false;
    final total = s?.totalConfirmed ?? 0;

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
                    widget.session.displayName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (isConfirmed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D9E75).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Confirmado ✓',
                      style: TextStyle(
                        color: Color(0xFF1D9E75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Horário: ${widget.session.startTime}',
              style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
            ),
            if (_loadingStatus) ...[
              const SizedBox(height: 8),
              const SizedBox(height: 4, child: LinearProgressIndicator()),
            ] else if (total > 0) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showConfirmants,
                child: Row(
                  children: [
                    _AvatarRow(confirmants: s?.confirmants ?? []),
                    const SizedBox(width: 8),
                    Text(
                      '$total ${total == 1 ? 'confirmado' : 'confirmados'} — ver quem',
                      style: const TextStyle(
                        color: Color(0xFF378ADD),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_acting)
              const Center(child: CircularProgressIndicator())
            else if (isConfirmed)
              OutlinedButton(
                onPressed: _cancel,
                child: const Text('Cancelar confirmação'),
              )
            else
              FilledButton.icon(
                onPressed: _loadingStatus ? null : _confirm,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Vou estar lá!'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  final List<Confirmant> confirmants;

  const _AvatarRow({required this.confirmants});

  @override
  Widget build(BuildContext context) {
    final show = confirmants.take(3).toList();
    return SizedBox(
      width: show.length * 22.0 + 4,
      height: 28,
      child: Stack(
        children: [
          for (int i = 0; i < show.length; i++)
            Positioned(
              left: i * 22.0,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                backgroundImage: show[i].avatarUrl != null
                    ? NetworkImage(show[i].avatarUrl!)
                    : null,
                child: show[i].avatarUrl == null
                    ? Text(
                        show[i].name.isNotEmpty ? show[i].name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _ConfirmantsSheet extends StatelessWidget {
  final String sessionName;
  final List<Confirmant> confirmants;

  const _ConfirmantsSheet({required this.sessionName, required this.confirmants});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Quem vai para $sessionName',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: confirmants.length,
            itemBuilder: (ctx, i) {
              final c = confirmants[i];
              final base = ApiService().baseUrl;
              final rawUrl = c.avatarUrl;
              final fullUrl = rawUrl == null
                  ? null
                  : rawUrl.startsWith('/')
                      ? '$base$rawUrl'
                      : rawUrl;
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: fullUrl != null ? NetworkImage(fullUrl) : null,
                  child: fullUrl == null
                      ? Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?')
                      : null,
                ),
                title: Text(c.name),
              );
            },
          ),
        ),
        SizedBox(height: MediaQuery.viewPaddingOf(context).bottom + 16),
      ],
    );
  }
}
