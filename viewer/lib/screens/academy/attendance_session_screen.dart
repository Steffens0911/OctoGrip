import 'dart:async' show StreamSubscription, TimeoutException, Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/attendance.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/attendance_live_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/models/face_recognition.dart';
import 'package:viewer/screens/academy/face_recognition_checkin_screen.dart';
import 'package:viewer/screens/academy/review_face_results_screen.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_screen_state.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';
import 'package:viewer/widgets/attendance_add_student_dialog.dart';

class AttendanceSessionScreen extends StatefulWidget {
  const AttendanceSessionScreen({super.key});

  @override
  State<AttendanceSessionScreen> createState() =>
      _AttendanceSessionScreenState();
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
  bool _startingSession = false;
  String? _error;
  bool _faceRecognitionEnabled = false;
  String? _faceJobId;
  DateTime? _faceJobSubmittedAt;
  bool _checkingFaceJob = false;
  Timer? _refreshTimer;
  Timer? _qrRetryTimer;
  Timer? _qrHeartbeatTimer;
  /// Último evento WebSocket útil (check-in/remoção); usado para não duplicar polling HTTP.
  DateTime? _lastWsActivityAt;
  bool _isRefreshingQr = false;
  bool _isRefreshingSession = false;
  String? _qrError;
  DateTime? _qrRefreshStartedAt;

  static const Duration _qrRequestTimeout = Duration(seconds: 25);
  static const String _qrTimeoutMessage =
      'Tempo esgotado ao gerar QR. Tentando novamente...';

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _stopLive();
    _refreshTimer?.cancel();
    _qrRetryTimer?.cancel();
    _qrHeartbeatTimer?.cancel();
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
    _lastWsActivityAt = DateTime.now();
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
        final others = _records
            .where((r) => r.userId != e.record.userId)
            .toList()
          ..add(e.record);
        // Mais recente primeiro.
        others.sort((a, b) => b.checkedInAt.compareTo(a.checkedInAt));
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
    final session = _session;
    final sid = session?.id;
    if (sid == null || session == null || _busy) return;
    final sessionAcademyId = session.academyId;
    final academyId = (sessionAcademyId != null && sessionAcademyId.isNotEmpty)
        ? sessionAcademyId
        : AuthService().currentUser?.academyId;
    if (academyId == null || academyId.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Nenhuma academia vinculada a esta chamada.',
        type: AppFeedbackType.error,
      );
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

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await _api.listAttendanceSessions(status: 'active', limit: 1);
      if (!mounted) return;
      if (sessions.isNotEmpty) {
        final s = sessions.first;
        setState(() {
          _session = s;
          _records = const [];
          _loading = false;
        });
        await _loadFaceFeatureFlag();
        _startAutoRefresh();
        _startQrHeartbeat();
        _startLive(s.id);

        final qrFuture = _api.getAttendanceQrPayload(s.id, ttlSeconds: 60);
        final recsFuture = _api.getAttendanceSessionRecordsAll(s.id);
        try {
          final qr = await qrFuture;
          if (!mounted) return;
          _applyQrPayload(qr);
        } catch (_) {}
        try {
          final recs = await recsFuture;
          if (!mounted) return;
          setState(() => _records = (recs.toList()..sort((a, b) => b.checkedInAt.compareTo(a.checkedInAt))));
          unawaited(_hydrateUsersForRecords(recs));
        } catch (_) {}
      } else {
        if (mounted) setState(() => _loading = false);
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

  static const Duration _refreshPollInterval = Duration(seconds: 15);
  /// Evita polling HTTP redundante quando o WS acabou de entregar atualização.
  static const Duration _skipPollAfterWsActivity = Duration(seconds: 12);

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    // Fallback lento se o WebSocket falhar (reconexão cobre a maioria dos casos).
    _refreshTimer = Timer.periodic(_refreshPollInterval, (_) {
      if (_session?.id == null) return;
      final last = _lastWsActivityAt;
      if (last != null &&
          DateTime.now().difference(last) < _skipPollAfterWsActivity) {
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
      await _loadFaceFeatureFlag();
      await _hydrateUsersForRecords(recs);
    } catch (_) {
      // Silencioso no auto refresh
    } finally {
      _isRefreshingSession = false;
    }
  }

  Future<void> _loadFaceFeatureFlag() async {
    final sid = _session?.academyId;
    if (sid == null || sid.isEmpty) {
      if (!mounted) return;
      setState(() => _faceRecognitionEnabled = false);
      return;
    }
    try {
      final academy = await _api.getAcademy(sid);
      if (!mounted) return;
      setState(() => _faceRecognitionEnabled = academy.faceRecognitionEnabled);
    } catch (_) {
      if (!mounted) return;
      setState(() => _faceRecognitionEnabled = false);
    }
  }

  Future<void> _openFaceRecognitionFlow() async {
    final session = _session;
    if (session == null || _busy) return;
    final result =
        await Navigator.of(context).push<FaceRecognitionSubmitResponse>(
      MaterialPageRoute(
        builder: (_) => FaceRecognitionCheckinScreen(sessionId: session.id),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _faceJobId = result.jobId;
      _faceJobSubmittedAt = DateTime.now();
    });
  }

  Future<void> _checkFaceRecognitionJob() async {
    final session = _session;
    final jobId = _faceJobId;
    if (session == null || jobId == null || _checkingFaceJob) return;
    setState(() => _checkingFaceJob = true);
    try {
      final job = await _api.getFaceRecognitionJob(jobId);
      if (!mounted) return;
      if (job.status == 'completed') {
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ReviewFaceResultsScreen(
              sessionId: session.id,
              jobId: jobId,
              academyId: session.academyId,
            ),
          ),
        );
        if (saved == true) {
          await _refreshSession();
          if (!mounted) return;
          setState(() {
            _faceJobId = null;
            _faceJobSubmittedAt = null;
          });
        }
      } else {
        AppFeedback.show(
          context,
          message:
              'Processamento ainda em andamento. Tente novamente em instantes.',
          type: AppFeedbackType.warning,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    } finally {
      if (mounted) setState(() => _checkingFaceJob = false);
    }
  }

  Future<void> _refreshQr({bool showErrors = false}) async {
    final s = _session;
    if (s == null || _isRefreshingQr) return;
    if ((s.status.toLowerCase() == 'closed')) return;
    _qrRetryTimer?.cancel();
    setState(() {
      _isRefreshingQr = true;
      _qrError = null;
      _qrRefreshStartedAt = DateTime.now();
    });
    try {
      final qr =
          await _api.getAttendanceQrPayload(s.id, ttlSeconds: 60).timeout(
                _qrRequestTimeout,
                onTimeout: () => throw TimeoutException(_qrTimeoutMessage),
              );
      if (!mounted) return;
      _applyQrPayload(qr);
      return;
    } catch (_) {
      // Retry curto para rede/proxy intermitente.
    }
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      final qr =
          await _api.getAttendanceQrPayload(s.id, ttlSeconds: 60).timeout(
                _qrRequestTimeout,
                onTimeout: () => throw TimeoutException(_qrTimeoutMessage),
              );
      if (!mounted) return;
      _applyQrPayload(qr);
    } catch (e) {
      if (!mounted) return;
      final msg = userFacingMessage(e);
      setState(() {
        _qr = null;
        _qrError = msg;
      });
      if (showErrors) {
        AppFeedback.show(
          context,
          message: msg,
          type: AppFeedbackType.error,
        );
      }
      _scheduleQrRetry();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingQr = false;
          _qrRefreshStartedAt = null;
        });
      }
      // Garantia extra: se sair sem QR, tenta novamente em breve.
      if (_qr == null) {
        _scheduleQrRetry();
      }
    }
  }

  Future<void> _safeRefreshQr({bool showErrors = false}) async {
    try {
      await _refreshQr(showErrors: showErrors);
    } catch (e) {
      if (!mounted) return;
      final msg = userFacingMessage(e);
      setState(() {
        _isRefreshingQr = false;
        _qrRefreshStartedAt = null;
        _qrError = msg;
      });
      if (showErrors) {
        AppFeedback.show(context, message: msg, type: AppFeedbackType.error);
      }
      _scheduleQrRetry();
    }
  }

  void _scheduleQrRetry({Duration delay = const Duration(seconds: 3)}) {
    final s = _session;
    if (!mounted || s == null) return;
    if (s.status.toLowerCase() == 'closed') return;
    _qrRetryTimer?.cancel();
    _qrRetryTimer = Timer(delay, () {
      if (!mounted) return;
      final current = _session;
      if (current == null || current.status.toLowerCase() == 'closed') return;
      if (_isRefreshingQr) return;
      unawaited(_safeRefreshQr());
    });
  }

  void _invalidateCurrentQrForRefresh() {
    setState(() {
      _qr = null;
      _qrError = null;
    });
  }

  Future<void> _forceRefreshQr() async {
    if (_busy) return;
    // Se travar em "Gerando...", o botão manual destrava o estado local.
    if (_isRefreshingQr && mounted) {
      setState(() {
        _isRefreshingQr = false;
        _qrRefreshStartedAt = null;
      });
    }
    _invalidateCurrentQrForRefresh();
    await _safeRefreshQr(showErrors: true);
  }

  void _applyQrPayload(AttendanceQrPayloadModel qr) {
    _qrRetryTimer?.cancel();
    setState(() {
      _qr = qr;
      _qrError = null;
    });
  }

  void _startQrHeartbeat() {
    _qrHeartbeatTimer?.cancel();
    _qrHeartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final s = _session;
      if (!mounted || s == null) return;
      if (s.status.toLowerCase() == 'closed') return;

      final sessionExp = s.expiresAt;
      if (sessionExp != null && sessionExp.isBefore(DateTime.now().toUtc())) {
        if (_qr != null || _qrError == null) {
          setState(() {
            _qr = null;
            _qrError = 'Sessão expirada. Encerre e inicie uma nova chamada.';
          });
        }
        return;
      }

      if (_isRefreshingQr) {
        final startedAt = _qrRefreshStartedAt;
        if (startedAt != null &&
            DateTime.now().difference(startedAt) >
                (_qrRequestTimeout + const Duration(seconds: 2))) {
          setState(() {
            _isRefreshingQr = false;
            _qrRefreshStartedAt = null;
          });
          _scheduleQrRetry(delay: const Duration(seconds: 1));
        }
        return;
      }

      final q = _qr;
      if (q == null || _secondsUntilQrExpiry(q.expiresAt) <= 0) {
        unawaited(_safeRefreshQr());
      }
    });
  }

  Future<void> _handleQrExpired() async {
    final s = _session;
    if (s == null || s.status.toLowerCase() == 'closed') return;
    // Evita corrida entre expiração e refresh já em andamento.
    if (_isRefreshingQr) {
      _scheduleQrRetry(delay: const Duration(seconds: 1));
      return;
    }
    _invalidateCurrentQrForRefresh();
    await _safeRefreshQr();
  }

  Future<void> _hydrateMissingUsers(
      Iterable<AttendanceRecordModel> recs) async {
    final missingIds = recs
        .map((r) => r.userId)
        .where((id) => !_userById.containsKey(id))
        .toSet()
        .toList();
    if (missingIds.isEmpty) return;

    Future<UserModel?> fetchOne(String id) async {
      try {
        return await _api.getUser(id);
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait(missingIds.map(fetchOne));
    if (!mounted) return;

    final additions = <String, UserModel>{};
    for (final u in results) {
      if (u != null) additions[u.id] = u;
    }
    if (additions.isEmpty) return;

    setState(() {
      _userById = {..._userById, ...additions};
    });
  }

  /// Pré-carrega o mapa de utilizadores (batch) e completa nomes em falta.
  Future<void> _hydrateUsersForRecords(List<AttendanceRecordModel> recs) async {
    if (_userById.isEmpty) {
      try {
        final isAdmin = AuthService().isAdmin();
        final academyId = AuthService().currentUser?.academyId;
        final users = await _api.getUsersAll(
          academyId: isAdmin ? null : academyId,
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Iniciar')),
        ],
      ),
    );
    final title = titleController.text.trim();
    titleController.dispose();
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
      });
      await _loadFaceFeatureFlag();
      _startAutoRefresh();
      _startQrHeartbeat();
      _startLive(s.id);

      // Busca QR e presenças em paralelo; prioriza o QR para reduzir espera.
      final qrFuture = _api.getAttendanceQrPayload(s.id, ttlSeconds: 60);
      final recsFuture = _api.getAttendanceSessionRecordsAll(s.id);

      final qr = await qrFuture;
      if (!mounted) return;
      _applyQrPayload(qr);

      try {
        final recs = await recsFuture;
        if (!mounted) return;
        setState(() => _records = recs);
        await _hydrateUsersForRecords(recs);
      } catch (_) {
        // ok: lista pode falhar por rede; WS + refresh continuam atualizando.
      }

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
    _qrRetryTimer?.cancel();
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
              icon: _startingSession
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_rounded),
              label:
                  Text(_startingSession ? 'Iniciando...' : 'Iniciar chamada'),
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
    final showFaceBanner = _faceJobId != null &&
        _faceJobSubmittedAt != null &&
        DateTime.now().difference(_faceJobSubmittedAt!).inMinutes >= 3;

    return RefreshIndicator(
      onRefresh: () async {
        await _refreshSession();
        await _safeRefreshQr(showErrors: true);
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
              if (_faceRecognitionEnabled)
                OutlinedButton.icon(
                  onPressed:
                      _busy || isClosed ? null : _openFaceRecognitionFlow,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Chamada por foto'),
                ),
            ],
          ),
          if (showFaceBanner) ...[
            const SizedBox(height: 8),
            Material(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _checkFaceRecognitionJob,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Processamento em andamento... Toque para verificar.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (_checkingFaceJob)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
                    RepaintBoundary(
                      child: QrImageView(
                        key: ValueKey<String>(qr.payload),
                        data: qr.payload,
                        size: 240,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    )
                  else
                    Container(
                      height: 240,
                      alignment: Alignment.center,
                      child: Text(
                        isClosed
                            ? 'Sessão encerrada'
                            : (_isRefreshingQr
                                ? 'Gerando novo QR...'
                                : 'QR expirado'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (qr != null && !isClosed)
                    _QrExpiryCountdownLabel(
                      key: ValueKey<String>('${qr.payload}_${qr.expiresAt.toIso8601String()}'),
                      expiresAt: qr.expiresAt,
                      textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryOf(context),
                          ),
                      onExpired: () => unawaited(_handleQrExpired()),
                    ),
                  if (qr == null && !isClosed) ...[
                    if (_qrError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _qrError!,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.red.shade400,
                                  ),
                        ),
                      ),
                  ],
                  if (!isClosed)
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () {
                              unawaited(_forceRefreshQr());
                            },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Gerar novo QR'),
                    ),
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
                final methodLabel = r.method == 'manual'
                    ? 'Manual'
                    : (r.method == 'qr'
                        ? 'QR'
                        : (r.method == 'face_recognition' || r.method == 'face' || r.faceRecognition
                            ? 'Facial'
                            : r.method));
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_rounded,
                      color: AppTheme.primary),
                  title: Text(label,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
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
              },
            ),
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

}

/// Atualiza apenas este texto ~1×/s; evita `setState` na raiz da [AttendanceSessionScreen].
class _QrExpiryCountdownLabel extends StatefulWidget {
  const _QrExpiryCountdownLabel({
    super.key,
    required this.expiresAt,
    required this.onExpired,
    required this.textStyle,
  });

  final DateTime expiresAt;
  final VoidCallback onExpired;
  final TextStyle? textStyle;

  @override
  State<_QrExpiryCountdownLabel> createState() =>
      _QrExpiryCountdownLabelState();
}

class _QrExpiryCountdownLabelState extends State<_QrExpiryCountdownLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final left = _secondsUntilQrExpiry(widget.expiresAt);
    if (left <= 0) {
      _timer?.cancel();
      widget.onExpired();
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final left = _secondsUntilQrExpiry(widget.expiresAt);
    final suffix =
        left <= 0 ? '0s' : _formatQrCountdown(left);
    return Text(
      'QR expira em $suffix',
      style: widget.textStyle,
    );
  }
}

int _secondsUntilQrExpiry(DateTime exp) {
  final now = DateTime.now().toUtc();
  final left = exp.toUtc().difference(now).inSeconds;
  return left < 0 ? 0 : left;
}

String _formatQrCountdown(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final mins = seconds ~/ 60;
  final secs = seconds % 60;
  final mm = mins.toString().padLeft(2, '0');
  final ss = secs.toString().padLeft(2, '0');
  return '$mm:$ss';
}
