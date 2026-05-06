import 'dart:async' show StreamSubscription, TimeoutException, Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/attendance.dart';
import 'package:viewer/models/attendance_qr.dart';
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
  const AttendanceSessionScreen({super.key, this.sessionId});

  /// Quando informado, carrega a sessão existente em vez de exibir "Iniciar chamada".
  final String? sessionId;

  @override
  State<AttendanceSessionScreen> createState() =>
      _AttendanceSessionScreenState();
}

class _AttendanceSessionScreenState extends State<AttendanceSessionScreen> {
  final _api = ApiService();
  AttendanceLiveService? _live;
  StreamSubscription<AttendanceLiveEvent>? _liveSub;

  AttendanceSessionModel? _session;
  QrTokenModel? _qr;
  String? _qrError;
  bool _refreshingQr = false;
  List<AttendanceRecordModel> _records = [];
  Map<String, UserModel> _userById = {};

  bool _loading = true;
  bool _busy = false;
  bool _startingSession = false;
  bool _qrAttendanceEnabled = true;
  String? _error;

  Timer? _refreshTimer;
  Timer? _qrHeartbeatTimer;
  DateTime? _lastWsActivityAt;
  bool _isRefreshingSession = false;

  static const Duration _pollInterval = Duration(seconds: 15);
  static const Duration _skipPollAfterWs = Duration(seconds: 12);
  static const Duration _qrTimeout = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _stopLive();
    _refreshTimer?.cancel();
    _qrHeartbeatTimer?.cancel();
    super.dispose();
  }

  // ── WebSocket ──────────────────────────────────────────────

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
    _lastWsActivityAt = DateTime.now();
    if (event is AttendanceCheckinLiveEvent) {
      if (s.id != event.record.sessionId) return;
      setState(() {
        _session = _copySession(s, presentCount: event.presentCount);
        final others = _records
            .where((r) => r.userId != event.record.userId)
            .toList()
          ..add(event.record);
        others.sort((a, b) => b.checkedInAt.compareTo(a.checkedInAt));
        _records = others;
      });
      unawaited(_hydrateMissingUsers([event.record]));
    } else if (event is AttendanceRecordRemovedLiveEvent) {
      if (s.id != event.sessionId) return;
      setState(() {
        _session = _copySession(s, presentCount: event.presentCount);
        _records = _records.where((r) => r.id != event.recordId).toList();
      });
    }
  }

  AttendanceSessionModel _copySession(AttendanceSessionModel s,
      {int? presentCount}) {
    return AttendanceSessionModel(
      id: s.id,
      academyId: s.academyId,
      createdByUserId: s.createdByUserId,
      status: s.status,
      title: s.title,
      startsAt: s.startsAt,
      endsAt: s.endsAt,
      expiresAt: s.expiresAt,
      presentCount: presentCount ?? s.presentCount,
    );
  }

  // ── QR heartbeat ───────────────────────────────────────────

  void _startQrHeartbeat() {
    if (!_qrAttendanceEnabled) return;
    _qrHeartbeatTimer?.cancel();
    _qrHeartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final s = _session;
      if (s == null || s.status.toLowerCase() == 'closed') return;
      if (_refreshingQr) return;
      final q = _qr;
      if (q == null || _secondsLeft(q.expiresAt) <= 5) {
        unawaited(_fetchQr());
      }
    });
  }

  Future<void> _fetchQr() async {
    final s = _session;
    if (!_qrAttendanceEnabled) return;
    if (s == null || s.status.toLowerCase() == 'closed') return;
    if (_refreshingQr) return;
    setState(() {
      _refreshingQr = true;
      _qrError = null;
    });
    try {
      final qr = await _api
          .getAttendanceQrToken(s.id, ttlSeconds: 60)
          .timeout(_qrTimeout, onTimeout: () => throw TimeoutException(null));
      if (!mounted) return;
      setState(() {
        _qr = qr;
        _qrError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _qr = null;
        _qrError = userFacingMessage(e);
      });
    } finally {
      if (mounted) setState(() => _refreshingQr = false);
    }
  }

  // ── Session polling ────────────────────────────────────────

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_pollInterval, (_) {
      if (_session?.id == null) return;
      final last = _lastWsActivityAt;
      if (last != null &&
          DateTime.now().difference(last) < _skipPollAfterWs) {
        return;
      }
      unawaited(_refreshSession());
    });
  }

  Future<void> _refreshSession() async {
    final s = _session;
    if (s == null || _isRefreshingSession) return;
    _isRefreshingSession = true;
    try {
      final updated = await _api.getAttendanceSession(s.id);
      final recs = await _api.getAttendanceSessionRecordsAll(s.id);
      if (!mounted) return;
      setState(() {
        _session = updated;
        _records = (recs.toList()
          ..sort((a, b) => b.checkedInAt.compareTo(a.checkedInAt)));
      });
      await _hydrateUsersForRecords(recs);
    } catch (_) {
      // silencioso
    } finally {
      _isRefreshingSession = false;
    }
  }

  // ── Usuários ───────────────────────────────────────────────

  Future<void> _hydrateMissingUsers(
      Iterable<AttendanceRecordModel> recs) async {
    final missing = recs
        .map((r) => r.userId)
        .where((id) => !_userById.containsKey(id))
        .toSet()
        .toList();
    if (missing.isEmpty) return;
    final results = await Future.wait(missing.map((id) async {
      try {
        return await _api.getUser(id);
      } catch (_) {
        return null;
      }
    }));
    if (!mounted) return;
    final add = <String, UserModel>{};
    for (final u in results) {
      if (u != null) add[u.id] = u;
    }
    if (add.isEmpty) return;
    setState(() => _userById = {..._userById, ...add});
  }

  Future<void> _hydrateUsersForRecords(List<AttendanceRecordModel> recs) async {
    if (_userById.isEmpty) {
      try {
        final isAdmin = AuthService().isAdmin();
        final academyId = AuthService().currentUser?.academyId;
        final users =
            await _api.getUsersAll(academyId: isAdmin ? null : academyId);
        if (!mounted) return;
        setState(() => _userById = {for (final u in users) u.id: u});
      } catch (_) {}
    }
    await _hydrateMissingUsers(recs);
  }

  // ── Ações ──────────────────────────────────────────────────

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final academyId = AuthService().currentUser?.academyId;
      if (academyId != null && academyId.isNotEmpty) {
        try {
          final academy = await _api.getAcademy(academyId);
          if (mounted) {
            setState(() => _qrAttendanceEnabled = academy.qrAttendanceEnabled);
          }
        } catch (_) {}
      }

      if (widget.sessionId != null) {
        await _loadExistingSession(widget.sessionId!);
        return;
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadExistingSession(String sessionId) async {
    try {
      final session = await _api.getAttendanceSession(sessionId);
      final recs = await _api.getAttendanceSessionRecordsAll(sessionId);
      if (!mounted) return;
      final isActive = session.status.toLowerCase() != 'closed';
      setState(() {
        _session = session;
        _records = (recs.toList()..sort((a, b) => b.checkedInAt.compareTo(a.checkedInAt)));
        _loading = false;
      });
      await _hydrateUsersForRecords(recs);
      if (!mounted) return;
      if (isActive) {
        _startAutoRefresh();
        _startLive(sessionId);
        if (_qrAttendanceEnabled) {
          _startQrHeartbeat();
          try {
            final qr = await _api.getAttendanceQrToken(sessionId, ttlSeconds: 60);
            if (mounted) setState(() => _qr = qr);
          } catch (e) {
            if (mounted) setState(() => _qrError = userFacingMessage(e));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(e);
          _loading = false;
        });
      }
    }
  }

  Set<String> get _presentUserIds => _records.map((r) => r.userId).toSet();

  Future<void> _addStudentDialog() async {
    final session = _session;
    final sid = session?.id;
    if (sid == null || session == null || _busy) return;
    final sessionAcademyId = session.academyId;
    final academyId = (sessionAcademyId != null && sessionAcademyId.isNotEmpty)
        ? sessionAcademyId
        : AuthService().currentUser?.academyId;
    if (academyId == null || academyId.isEmpty) {
      AppFeedback.show(context,
          message: 'Nenhuma academia vinculada a esta chamada.',
          type: AppFeedbackType.error);
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => AttendanceAddStudentDialog(
        api: _api,
        academyId: academyId,
        presentUserIds: _presentUserIds,
        onConfirm: (ids) => _api.addAttendanceRecordsManualBatch(sid, ids),
      ),
    );
    if (mounted) unawaited(_refreshSession());
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _api.deleteAttendanceRecord(r.id);
      final updated = await _api.getAttendanceSession(sid);
      final recs = await _api.getAttendanceSessionRecordsAll(sid);
      if (!mounted) return;
      setState(() {
        _session = updated;
        _records = (recs.toList()
          ..sort((a, b) => b.checkedInAt.compareTo(a.checkedInAt)));
        _busy = false;
      });
      AppFeedback.show(context,
          message: 'Presença removida', type: AppFeedbackType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.show(context,
          message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _startSession() async {
    if (_busy) return;
    final titleCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Iniciar chamada'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Título (opcional)',
            hintText: 'Ex.: Treino 19h',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Iniciar')),
        ],
      ),
    );
    final title = titleCtrl.text.trim();
    titleCtrl.dispose();
    if (ok != true) return;

    setState(() {
      _busy = true;
      _startingSession = true;
    });
    try {
      final s = await _api.createAttendanceSession(
          title: title.isEmpty ? null : title, expiresInMinutes: 20);
      if (!mounted) return;
      setState(() {
        _session = s;
        _records = const [];
        _qr = null;
        _qrError = null;
      });
      _startAutoRefresh();
      _startLive(s.id);
      final recsFuture = _api.getAttendanceSessionRecordsAll(s.id);
      if (_qrAttendanceEnabled) {
        _startQrHeartbeat();
        try {
          final qr = await _api.getAttendanceQrToken(s.id, ttlSeconds: 60);
          if (!mounted) return;
          setState(() => _qr = qr);
        } catch (e) {
          if (!mounted) return;
          setState(() => _qrError = userFacingMessage(e));
        }
      } else {
        _qrHeartbeatTimer?.cancel();
        if (mounted) {
          setState(() {
            _qr = null;
            _qrError =
                'QR desativado nesta academia. Registre presença manualmente.';
          });
        }
      }

      try {
        final recs = await recsFuture;
        if (!mounted) return;
        setState(() => _records = recs);
        await _hydrateUsersForRecords(recs);
      } catch (_) {}

      if (!mounted) return;
      AppFeedback.show(context,
          message: 'Chamada iniciada', type: AppFeedbackType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _startingSession = false;
      });
      AppFeedback.show(context,
          message: userFacingMessage(e), type: AppFeedbackType.error);
      return;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _startingSession = false;
        });
      }
    }
  }

  Future<void> _closeSession() async {
    final s = _session;
    if (s == null || _busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar chamada'),
        content: const Text(
            'Depois de encerrar, alunos não conseguem mais registrar presença.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Encerrar')),
        ],
      ),
    );
    if (ok != true) return;

    _stopLive();
    _qrHeartbeatTimer?.cancel();
    setState(() => _busy = true);
    try {
      final closed = await _api.closeAttendanceSession(s.id);
      final recs = await _api.getAttendanceSessionRecordsAll(s.id);
      if (!mounted) return;
      setState(() {
        _session = closed;
        _records = (recs.toList()
          ..sort((a, b) => b.checkedInAt.compareTo(a.checkedInAt)));
        _qr = null;
        _qrError = null;
        _busy = false;
      });
      AppFeedback.show(context,
          message: 'Chamada encerrada', type: AppFeedbackType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.show(context,
          message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Chamada'),
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
              _qrAttendanceEnabled
                  ? 'Inicie uma chamada para exibir o QR na sala.'
                  : 'Inicie uma chamada para registrar presença manualmente.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _startSession,
              icon: _startingSession
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_rounded),
              label: Text(_startingSession ? 'Iniciando...' : 'Iniciar chamada'),
            ),
            const SizedBox(height: 12),
            Text(
              _qrAttendanceEnabled
                  ? 'O QR é renovado automaticamente. Os alunos escaneiam com o app para registrar presença.'
                  : 'Nesta academia, o QR está desativado. Use "Adicionar aluno" para registrar presença manual.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
          ],
        ),
      );
    }

    final isClosed = s.status.toLowerCase() == 'closed';

    return RefreshIndicator(
      onRefresh: () async {
        await _refreshSession();
        if (!isClosed && _qrAttendanceEnabled) await _fetchQr();
      },
      child: ListView(
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
        children: [
          // ── Header ──
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
          if (!isClosed)
            OutlinedButton.icon(
              onPressed: _busy ? null : _addStudentDialog,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Adicionar aluno'),
            ),
          const SizedBox(height: 8),
          Text(
            'Presentes: ${s.presentCount}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
          const SizedBox(height: 16),

          // ── QR Card ──
          if (!isClosed)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!_qrAttendanceEnabled)
                      SizedBox(
                        height: 240,
                        child: Center(
                          child: Text(
                            'QR desativado nesta academia.\nUse "Adicionar aluno" para presença manual.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else if (_qr != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Código manual (quem não consegue escanear):',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: AppTheme.textSecondaryOf(context),
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _qr!.shortCode,
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 6,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copiar código',
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _qr!.shortCode));
                                AppFeedback.show(context,
                                    message: 'Código copiado',
                                    type: AppFeedbackType.success);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      RepaintBoundary(
                        child: QrImageView(
                          key: ValueKey<String>(_qr!.token),
                          data: _qr!.token,
                          size: 240,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                        ),
                      ),
                    ]
                    else
                      SizedBox(
                        height: 240,
                        child: Center(
                          child: _refreshingQr
                              ? const CircularProgressIndicator()
                              : Text(
                                  _qrError ?? 'Gerando QR...',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: _qrError != null
                                            ? Colors.red.shade400
                                            : null,
                                      ),
                                ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (_qrAttendanceEnabled && _qr != null)
                      _QrCountdown(
                        key: ValueKey(_qr!.token),
                        expiresAt: _qr!.expiresAt,
                        textStyle:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondaryOf(context),
                                ),
                      ),
                    const SizedBox(height: 8),
                    if (_qrAttendanceEnabled)
                      OutlinedButton.icon(
                        onPressed: (_busy || _refreshingQr) ? null : _fetchQr,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Gerar novo QR'),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // ── Lista de presenças ──
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
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final r = _records[index];
                final u = _userById[r.userId];
                final label = u != null
                    ? ((u.name ?? '').trim().isNotEmpty
                        ? u.name!.trim()
                        : u.email)
                    : r.userId;
                final methodLabel = switch (r.method) {
                  'manual' => 'Manual',
                  'qr' => 'QR',
                  'face_recognition' || 'face' => 'Facial',
                  _ => r.method,
                };
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_rounded,
                      color: AppTheme.primary),
                  title: Text(label,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${_fmt(r.checkedInAt)} · $methodLabel',
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
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final l = dt.toLocal();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(l.day)}/${p(l.month)} ${p(l.hour)}:${p(l.minute)}';
  }
}

// ── Countdown widget ───────────────────────────────────────────────────────────

class _QrCountdown extends StatefulWidget {
  const _QrCountdown({
    super.key,
    required this.expiresAt,
    this.textStyle,
  });

  final DateTime expiresAt;
  final TextStyle? textStyle;

  @override
  State<_QrCountdown> createState() => _QrCountdownState();
}

class _QrCountdownState extends State<_QrCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _secondsLeft(widget.expiresAt);
    return Text(
      left > 0 ? 'QR expira em ${_fmtCountdown(left)}' : 'QR expirado',
      style: widget.textStyle,
    );
  }
}

int _secondsLeft(DateTime exp) {
  final left = exp.toUtc().difference(DateTime.now().toUtc()).inSeconds;
  return left < 0 ? 0 : left;
}

String _fmtCountdown(int s) {
  if (s < 60) return '${s}s';
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}
