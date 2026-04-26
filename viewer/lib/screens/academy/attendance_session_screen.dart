import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

class AttendanceSessionScreen extends StatefulWidget {
  const AttendanceSessionScreen({super.key});

  @override
  State<AttendanceSessionScreen> createState() => _AttendanceSessionScreenState();
}

class _AttendanceSessionScreenState extends State<AttendanceSessionScreen> {
  final _api = ApiService();
  AttendanceLiveService? _live;
  StreamSubscription<AttendanceLiveEvent>? _liveSub;

  AttendanceSessionModel? _session;
  AttendanceQrPayloadModel? _qr;
  List<AttendanceRecordModel> _records = [];
  Map<String, UserModel> _userById = {};

  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  int _qrSecondsLeft = 0;
  bool _isRefreshingQr = false;
  bool _isRefreshingSession = false;
  bool _qrPrefetchTriggered = false;
  String? _qrError;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _stopLive();
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _stopLive() {
    _liveSub?.cancel();
    _liveSub = null;
    _live?.dispose();
    _live = null;
  }

  void _startLive(String sessionId) {
    _stopLive();
    final live = AttendanceLiveService();
    _live = live;
    _liveSub = live.stream.listen(_onLiveEvent);
    live.connect(sessionId);
  }

  void _onLiveEvent(AttendanceLiveEvent event) {
    final s = _session;
    if (!mounted || s == null) return;
    if (event is AttendanceCheckinLiveEvent) {
      final e = event;
      if (s.id != e.record.sessionId) return;
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
          presentCount: e.presentCount,
        );
        final others = _records.where((r) => r.userId != e.record.userId).toList()..add(e.record);
        others.sort((a, b) => a.checkedInAt.compareTo(b.checkedInAt));
        _records = others;
      });
      unawaited(_hydrateMissingUsers([e.record]));
    } else if (event is AttendanceRecordRemovedLiveEvent) {
      if (s.id != event.sessionId) return;
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

  Set<String> get _presentUserIds => _records.map((r) => r.userId).toSet();

  Future<void> _addStudentDialog() async {
    final sid = _session?.id;
    if (sid == null || _busy) return;
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
          await _addStudentManual(sid, userId);
        },
      ),
    );
  }

  Future<void> _addStudentManual(String sessionId, String userId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _api.addAttendanceRecord(sessionId, userId);
      final updated = await _api.getAttendanceSession(sessionId);
      final recs = await _api.getAttendanceSessionRecords(sessionId, limit: 500);
      if (!mounted) return;
      setState(() {
        _session = updated;
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

  Future<void> _confirmRemoveRecord(AttendanceRecordModel r) async {
    final sid = _session?.id;
    if (sid == null || _busy) return;
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
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _api.deleteAttendanceRecord(r.id);
      final updated = await _api.getAttendanceSession(sid);
      final recs = await _api.getAttendanceSessionRecords(sid, limit: 500);
      if (!mounted) return;
      setState(() {
        _session = updated;
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

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Não há "sessão ativa" persistida ainda; tela começa vazia.
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = userFacingMessage(e); _loading = false; });
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    // Fallback lento se o WebSocket falhar (reconexão cobre a maioria dos casos).
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_session?.id != null) {
        unawaited(_refreshSession());
      }
    });
  }

  Future<void> _refreshSession() async {
    final s = _session;
    if (s == null || _isRefreshingSession) return;
    _isRefreshingSession = true;
    try {
      final updated = await _api.getAttendanceSession(s.id);
      final recs = await _api.getAttendanceSessionRecords(s.id, limit: 500);
      if (!mounted) return;
      setState(() {
        _session = updated;
        _records = recs;
      });
      await _hydrateUsersForRecords(recs);
    } catch (_) {
      // Silencioso no auto refresh
    } finally {
      _isRefreshingSession = false;
    }
  }

  Future<void> _refreshQr({bool showErrors = false}) async {
    final s = _session;
    if (s == null || _isRefreshingQr) return;
    if ((s.status.toLowerCase() == 'closed')) return;
    setState(() {
      _isRefreshingQr = true;
      _qrError = null;
    });
    try {
      final qr = await _api.getAttendanceQrPayload(s.id, ttlSeconds: 60);
      if (!mounted) return;
      _applyQrPayload(qr);
      return;
    } catch (_) {
      // Retry curto para rede/proxy intermitente.
    }
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      final qr = await _api.getAttendanceQrPayload(s.id, ttlSeconds: 60);
      if (!mounted) return;
      _applyQrPayload(qr);
    } catch (e) {
      if (!mounted) return;
      final msg = userFacingMessage(e);
      setState(() {
        _qr = null;
        _qrSecondsLeft = 0;
        _qrError = msg;
      });
      if (showErrors) {
        AppFeedback.show(
          context,
          message: msg,
          type: AppFeedbackType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingQr = false);
      }
    }
  }

  void _applyQrPayload(AttendanceQrPayloadModel qr) {
    final initialSeconds = _secondsUntil(qr.expiresAt);
    _countdownTimer?.cancel();
    setState(() {
      _qr = qr;
      _qrError = null;
      _qrSecondsLeft = initialSeconds;
      _qrPrefetchTriggered = false;
    });
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_qr == null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_qrSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _qrSecondsLeft = 0);
        unawaited(_handleQrExpired());
        return;
      }
      if (_qrSecondsLeft <= 5 && !_qrPrefetchTriggered && !_isRefreshingQr) {
        _qrPrefetchTriggered = true;
        unawaited(_refreshQr());
      }
      setState(() => _qrSecondsLeft -= 1);
    });
  }

  Future<void> _handleQrExpired() async {
    final s = _session;
    if (s == null || s.status.toLowerCase() == 'closed') return;
    // Invalida visualmente o QR expirado antes de buscar o próximo.
    if (mounted) {
      setState(() => _qr = null);
    }
    await _refreshQr();
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
      } catch (_) {
        // ok
      }
    }
  }

  /// Pré-carrega o mapa de utilizadores (batch) e completa nomes em falta.
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
      } catch (_) {
        // ok
      }
    }
    await _hydrateMissingUsers(recs);
  }

  Future<void> _startSession() async {
    if (_busy) return;
    final titleController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Iniciar chamada'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Título (opcional)',
            hintText: 'Ex.: Treino 19h',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Iniciar')),
        ],
      ),
    );
    final title = titleController.text.trim();
    titleController.dispose();
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final s = await _api.createAttendanceSession(title: title.isEmpty ? null : title, expiresInMinutes: 20);
      final qr = await _api.getAttendanceQrPayload(s.id, ttlSeconds: 60);
      final recs = await _api.getAttendanceSessionRecords(s.id, limit: 500);
      if (!mounted) return;
      setState(() {
        _session = s;
        _records = recs;
        _busy = false;
      });
      _applyQrPayload(qr);
      _startAutoRefresh();
      _startLive(s.id);
      AppFeedback.show(context, message: 'Chamada iniciada', type: AppFeedbackType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _closeSession() async {
    final s = _session;
    if (s == null || _busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar chamada'),
        content: const Text('Depois de encerrar, alunos não conseguem mais registrar presença.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Encerrar')),
        ],
      ),
    );
    if (ok != true) return;

    _stopLive();
    setState(() => _busy = true);
    try {
      final closed = await _api.closeAttendanceSession(s.id);
      final recs = await _api.getAttendanceSessionRecords(s.id, limit: 500);
      if (!mounted) return;
      setState(() {
        _session = closed;
        _records = recs;
        _qr = null;
        _qrError = null;
        _qrSecondsLeft = 0;
        _busy = false;
      });
      _countdownTimer?.cancel();
      AppFeedback.show(context, message: 'Chamada encerrada', type: AppFeedbackType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Chamada (QR)'),
      body: _loading
          ? const AppScreenState.loading()
          : _error != null
              ? AppScreenState.error(message: _error!, onRetry: _loadInitial)
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final s = _session;
    if (s == null) {
      return Padding(
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Inicie uma chamada para exibir o QR na sala.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _startSession,
              icon: const Icon(Icons.qr_code_rounded),
              label: const Text('Iniciar chamada'),
            ),
            const SizedBox(height: 12),
            Text(
              'O QR muda automaticamente. Os alunos escaneiam para registrar presença.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
          ],
        ),
      );
    }

    final qr = _qr;
    final isClosed = (s.status.toLowerCase() == 'closed');

    return RefreshIndicator(
      onRefresh: () async {
        await _refreshSession();
        await _refreshQr(showErrors: true);
      },
      child: ListView(
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.title?.isNotEmpty == true ? s.title! : 'Chamada ativa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (!isClosed)
                FilledButton(
                  onPressed: _busy ? null : _closeSession,
                  child: const Text('Encerrar'),
                )
              else
                const Chip(label: Text('Encerrada')),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _addStudentDialog,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Adicionar aluno'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Presentes: ${s.presentCount}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (qr != null && !isClosed)
                    QrImageView(
                      key: ValueKey<String>(qr.payload),
                      data: qr.payload,
                      size: 240,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    )
                  else
                    Container(
                      height: 240,
                      alignment: Alignment.center,
                      child: Text(
                        isClosed
                            ? 'Sessão encerrada'
                            : (_isRefreshingQr ? 'Gerando novo QR...' : 'QR expirado'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (qr != null && !isClosed)
                    Text(
                      'QR expira em ${_formatCountdown(_qrSecondsLeft)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryOf(context),
                          ),
                    ),
                  if (qr == null && !isClosed) ...[
                    if (_qrError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _qrError!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.red.shade400,
                              ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: (_busy || _isRefreshingQr)
                          ? null
                          : () {
                              unawaited(_refreshQr(showErrors: true));
                            },
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(_isRefreshingQr ? 'Gerando...' : 'Gerar novo QR'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Presenças', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_records.isEmpty)
            Text(
              'Ninguém registrou presença ainda.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            )
          else
            ..._records.map((r) {
              final u = _userById[r.userId];
              final label = u != null
                  ? '${u.email}${u.name != null && u.name!.trim().isNotEmpty ? ' • ${u.name}' : ''}'
                  : r.userId;
              final methodLabel =
                  r.method == 'manual' ? 'Manual' : (r.method == 'qr' ? 'QR' : r.method);
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
                  onPressed: _busy ? null : () => _confirmRemoveRecord(r),
                ),
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  int _secondsUntil(DateTime exp) {
    final now = DateTime.now().toUtc();
    final left = exp.difference(now).inSeconds;
    return left < 0 ? 0 : left;
  }

  String _formatCountdown(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    final mm = mins.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

