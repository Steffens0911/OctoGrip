import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/attendance.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/attendance_live_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_screen_state.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';
import 'package:viewer/widgets/attendance_add_student_dialog.dart';

/// Detalhe de uma sessão de chamada: presentes, adicionar manualmente, remover, encerrar.
class AttendanceSessionDetailScreen extends StatefulWidget {
  const AttendanceSessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<AttendanceSessionDetailScreen> createState() => _AttendanceSessionDetailScreenState();
}

class _AttendanceSessionDetailScreenState extends State<AttendanceSessionDetailScreen> {
  final _api = ApiService();
  AttendanceLiveService? _live;
  StreamSubscription<AttendanceLiveEvent>? _liveSub;

  AttendanceSessionModel? _session;
  List<AttendanceRecordModel> _records = [];
  Map<String, UserModel> _userById = {};
  UserModel? _createdBy;

  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _stopLive();
    super.dispose();
  }

  void _stopLive() {
    _liveSub?.cancel();
    _liveSub = null;
    _live?.dispose();
    _live = null;
  }

  void _startLive() {
    _stopLive();
    final live = AttendanceLiveService();
    _live = live;
    _liveSub = live.stream.listen(_onLiveEvent);
    live.connect(widget.sessionId);
  }

  void _onLiveEvent(AttendanceLiveEvent event) {
    final s = _session;
    if (!mounted || s == null) return;
    if (event is AttendanceCheckinLiveEvent) {
      if (s.id != event.record.sessionId) return;
      setState(() {
        _session = AttendanceSessionModel(
          id: s.id,
          academyId: s.academyId,
          createdByUserId: s.createdByUserId,
          status: s.status,
          title: s.title,
          startsAt: s.startsAt,
          endsAt: s.endsAt,
          expiresAt: s.expiresAt,
          presentCount: event.presentCount,
        );
        final others = _records.where((r) => r.userId != event.record.userId).toList()..add(event.record);
        others.sort((a, b) => a.checkedInAt.compareTo(b.checkedInAt));
        _records = others;
      });
      unawaited(_hydrateMissingUsers([event.record]));
    } else if (event is AttendanceRecordRemovedLiveEvent) {
      if (event.sessionId != s.id) return;
      setState(() {
        _session = AttendanceSessionModel(
          id: s.id,
          academyId: s.academyId,
          createdByUserId: s.createdByUserId,
          status: s.status,
          title: s.title,
          startsAt: s.startsAt,
          endsAt: s.endsAt,
          expiresAt: s.expiresAt,
          presentCount: event.presentCount,
        );
        _records = _records.where((r) => r.id != event.recordId).toList();
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await _api.getAttendanceSession(widget.sessionId);
      final recs = await _api.getAttendanceSessionRecords(widget.sessionId, limit: 500);
      UserModel? creator;
      try {
        creator = await _api.getUser(session.createdByUserId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _session = session;
        _records = recs;
        _createdBy = creator;
        _loading = false;
      });
      await _hydrateUsersForRecords(recs);
      _startLive();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _hydrateMissingUsers(Iterable<AttendanceRecordModel> recs) async {
    for (final r in recs) {
      if (_userById.containsKey(r.userId)) continue;
      try {
        final u = await _api.getUser(r.userId);
        if (!mounted) return;
        setState(() {
          _userById = {..._userById, r.userId: u};
        });
      } catch (_) {}
    }
  }

  Future<void> _hydrateUsersForRecords(List<AttendanceRecordModel> recs) async {
    if (_userById.isEmpty) {
      try {
        final isAdmin = AuthService().isAdmin();
        final academyId = AuthService().currentUser?.academyId;
        final users = await _api.getUsers(
          academyId: isAdmin ? null : academyId,
          offset: 0,
          limit: 500,
        );
        if (!mounted) return;
        setState(() {
          _userById = {for (final u in users) u.id: u};
        });
      } catch (_) {}
    }
    await _hydrateMissingUsers(recs);
  }

  Future<void> _closeSession() async {
    final s = _session;
    if (s == null || _busy || s.status.toLowerCase() == 'closed') return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar chamada'),
        content: const Text('Depois de encerrar, alunos não conseguem mais registrar presença via QR.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Encerrar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final closed = await _api.closeAttendanceSession(s.id);
      final recs = await _api.getAttendanceSessionRecords(s.id, limit: 500);
      if (!mounted) return;
      setState(() {
        _session = closed;
        _records = recs;
        _busy = false;
      });
      AppFeedback.show(context, message: 'Chamada encerrada', type: AppFeedbackType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Set<String> get _presentUserIds => _records.map((r) => r.userId).toSet();

  Future<void> _addStudentDialog() async {
    final academyId = AuthService().currentUser?.academyId;
    if (academyId == null && !AuthService().isAdmin()) {
      AppFeedback.show(
        context,
        message: 'Utilizador sem academia vinculada.',
        type: AppFeedbackType.error,
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AttendanceAddStudentDialog(
        api: _api,
        academyId: academyId,
        presentUserIds: _presentUserIds,
        onPick: (userId) async {
          Navigator.pop(ctx);
          await _addStudent(userId);
        },
      ),
    );
  }

  Future<void> _addStudent(String userId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _api.addAttendanceRecord(widget.sessionId, userId);
      final session = await _api.getAttendanceSession(widget.sessionId);
      final recs = await _api.getAttendanceSessionRecords(widget.sessionId, limit: 500);
      if (!mounted) return;
      setState(() {
        _session = session;
        _records = recs;
        _busy = false;
      });
      await _hydrateUsersForRecords(recs);
      if (!mounted) return;
      AppFeedback.show(context, message: 'Presença adicionada', type: AppFeedbackType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _confirmRemove(AttendanceRecordModel r) async {
    final u = _userById[r.userId];
    final label = u != null
        ? '${u.email}${u.name != null && u.name!.trim().isNotEmpty ? ' · ${u.name}' : ''}'
        : r.userId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover presença'),
        content: Text('Remover presença de $label?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _api.deleteAttendanceRecord(r.id);
      final session = await _api.getAttendanceSession(widget.sessionId);
      final recs = await _api.getAttendanceSessionRecords(widget.sessionId, limit: 500);
      if (!mounted) return;
      setState(() {
        _session = session;
        _records = recs;
        _busy = false;
      });
      AppFeedback.show(context, message: 'Presença removida', type: AppFeedbackType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Detalhe da chamada'),
      body: _loading
          ? const AppScreenState.loading()
          : _error != null
              ? AppScreenState.error(message: _error!, onRetry: _load)
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final s = _session!;
    final isClosed = s.status.toLowerCase() == 'closed';
    final title = s.title?.isNotEmpty == true ? s.title! : 'Chamada';
    final creatorLabel = _createdBy != null
        ? '${_createdBy!.email}${_createdBy!.name != null && _createdBy!.name!.trim().isNotEmpty ? ' · ${_createdBy!.name}' : ''}'
        : s.createdByUserId;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            isClosed ? 'Encerrada' : 'Ativa',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
          Text(
            'Início: ${_formatDateTime(s.startsAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
          Text(
            'Criada por: $creatorLabel',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
          Text(
            'Presentes: ${s.presentCount}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!isClosed)
                FilledButton(
                  onPressed: _busy ? null : _closeSession,
                  child: const Text('Encerrar chamada'),
                ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _addStudentDialog,
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Adicionar aluno'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Lista de presenças', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_records.isEmpty)
            Text(
              'Nenhuma presença registada.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            )
          else
            ..._records.map((r) {
              final u = _userById[r.userId];
              final label = u != null ? ((u.name ?? '').trim().isNotEmpty ? u.name!.trim() : u.email) : r.userId;
              final methodLabel = r.method == 'manual' ? 'Manual' : (r.method == 'qr' ? 'QR' : r.method);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
                title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${_formatDateTime(r.checkedInAt)} · $methodLabel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
                trailing: IconButton(
                  tooltip: 'Remover presença',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: _busy ? null : () => _confirmRemove(r),
                ),
              );
            }),
        ],
      ),
    );
  }
}
