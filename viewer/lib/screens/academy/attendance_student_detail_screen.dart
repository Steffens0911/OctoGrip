import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/attendance.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_screen_state.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Histórico detalhado de presenças de um aluno no período.
class AttendanceStudentDetailScreen extends StatefulWidget {
  const AttendanceStudentDetailScreen({
    super.key,
    required this.studentId,
    required this.period,
    this.academyId,
  });

  final String studentId;
  final DateTimeRange period;
  final String? academyId;

  @override
  State<AttendanceStudentDetailScreen> createState() => _AttendanceStudentDetailScreenState();
}

class _AttendanceStudentDetailScreenState extends State<AttendanceStudentDetailScreen> {
  final _api = ApiService();
  AttendanceStudentDetailModel? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _api.getAttendanceStatsStudent(
        widget.studentId,
        academyId: widget.academyId,
        from: widget.period.start,
        to: widget.period.end,
      );
      if (!mounted) return;
      setState(() {
        _detail = d;
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

  String _formatDt(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  String _methodLabel(String m) {
    switch (m.toLowerCase()) {
      case 'manual':
        return 'Manual';
      case 'qr':
        return 'QR';
      default:
        return m;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Frequência do aluno'),
      body: _loading
          ? const AppScreenState.loading()
          : _error != null
              ? AppScreenState.error(message: _error!, onRetry: _load)
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final d = _detail!;
    final pct = (d.attendanceRate * 100).toStringAsFixed(1);
    final title = d.name != null && d.name!.trim().isNotEmpty ? d.name!.trim() : d.email;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          Text(
            d.email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
          if (d.graduation != null && d.graduation!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Graduação: ${d.graduation}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            '${d.presentCount} presença(s) · $pct% de frequência (${d.totalSessions} sessões no período)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (d.lastSeenAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Última presença: ${_formatDt(d.lastSeenAt!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
            ),
          const SizedBox(height: 20),
          Text('Histórico', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (d.records.isEmpty)
            Text(
              'Nenhuma presença neste período.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            )
          else
            ...d.records.map((r) {
              final sessTitle = r.sessionTitle?.trim().isNotEmpty == true
                  ? r.sessionTitle!.trim()
                  : 'Chamada';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_rounded, color: AppTheme.primary),
                title: Text(sessTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${_formatDt(r.sessionStartsAt)} · ${_methodLabel(r.method)} · check-in ${_formatDt(r.checkedInAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
