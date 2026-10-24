import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:viewer/models/photo_moderation.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Denúncias abertas do feed de fotos para gerentes e administradores:
/// manter o conteúdo ou removê-lo.
class PhotoReportsScreen extends StatefulWidget {
  const PhotoReportsScreen({super.key, required this.academyId});

  final String academyId;

  @override
  State<PhotoReportsScreen> createState() => _PhotoReportsScreenState();
}

class _PhotoReportsScreenState extends State<PhotoReportsScreen> {
  late Future<List<PhotoReport>> _future;
  String? _resolving;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getPhotoReports(widget.academyId);
  }

  void _reload() {
    setState(() {
      _future = ApiService().getPhotoReports(widget.academyId);
    });
  }

  Future<void> _resolve(PhotoReport r, String action) async {
    if (action == 'remove') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(r.isComment ? 'Remover comentário?' : 'Remover post?'),
          content: const Text(
              'O conteúdo sai do feed para todos. Isso não pode ser desfeito.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remover'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _resolving = r.id);
    try {
      await ApiService().resolvePhotoReport(widget.academyId, r.id, action);
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: action == 'remove'
            ? 'Conteúdo removido.'
            : 'Denúncia encerrada, conteúdo mantido.',
        type: AppFeedbackType.success,
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(context,
          message: userFacingMessage(e), type: AppFeedbackType.error);
    } finally {
      if (mounted) setState(() => _resolving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Denúncias do feed'),
      body: FutureBuilder<List<PhotoReport>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(userFacingMessage(snap.error!),
                    textAlign: TextAlign.center),
              ),
            );
          }
          final reports = snap.data ?? const <PhotoReport>[];
          if (reports.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhuma denúncia aberta.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: reports.length,
              itemBuilder: (context, i) => _ReportCard(
                report: reports[i],
                busy: _resolving == reports[i].id,
                onResolve: (action) => _resolve(reports[i], action),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.busy,
    required this.onResolve,
  });

  final PhotoReport report;
  final bool busy;
  final void Function(String action) onResolve;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final when =
        DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt.toLocal());
    final text = (report.targetText ?? '').trim();
    return Card(
      key: Key('report-${report.id}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${report.isComment ? 'Comentário' : 'Post'} de ${report.targetAuthorName ?? 'usuário'}',
              style: tt.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              text.isEmpty ? '(sem texto)' : text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Motivo: ${photoReportReasonLabel(report.reason)}'
              '${(report.details ?? '').trim().isEmpty ? '' : ' — ${report.details!.trim()}'}',
              style: tt.bodySmall,
            ),
            Text(
              'Denunciado por ${report.reporterName ?? 'um membro'} em $when'
              '${report.reportsOnTarget > 1 ? ' · ${report.reportsOnTarget} denúncias' : ''}',
              style: tt.bodySmall,
            ),
            if (report.targetRemoved)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Já removido.', style: tt.bodySmall),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: Key('dismiss-${report.id}'),
                  onPressed: busy ? null : () => onResolve('dismiss'),
                  child: const Text('Manter'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: Key('remove-${report.id}'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: busy ? null : () => onResolve('remove'),
                  child: const Text('Remover'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
