import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/attendance.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_screen_state.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class AttendanceSessionScreen extends StatefulWidget {
  const AttendanceSessionScreen({super.key});

  @override
  State<AttendanceSessionScreen> createState() => _AttendanceSessionScreenState();
}

class _AttendanceSessionScreenState extends State<AttendanceSessionScreen> {
  final _api = ApiService();

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
  String? _qrError;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
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
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_session?.id != null) {
        unawaited(_refreshSession());
      }
    });
  }

  Future<void> _refreshSession() async {
    final s = _session;
    if (s == null) return;
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

  Future<void> _hydrateUsersForRecords(List<AttendanceRecordModel> recs) async {
    // Hoje a API não tem endpoint específico de "users/byIds". Para manter simples:
    // - em Admin/Academy panel já existe listagem de usuários; reutilizamos cache do ApiService getUsers.
    // - carregamos só uma vez e indexamos em memória.
    if (_userById.isNotEmpty) return;
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
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
                title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  _formatDateTime(r.checkedInAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
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

