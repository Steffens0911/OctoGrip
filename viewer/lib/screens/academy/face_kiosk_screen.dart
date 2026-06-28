import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:viewer/models/attendance_qr.dart';
import 'package:viewer/models/face_checkin.dart';

/// Quiosque de reconhecimento facial com câmera ao vivo e QR Code alternativo.
///
/// Callbacks injetáveis permitem substituição por mocks nos testes sem imports web:
/// - [setupCamera] inicializa câmera e registra a platform view para [cameraViewId].
/// - [detectFace] retorna true se há rosto no frame atual da câmera.
/// - [captureJpeg] captura o frame atual como JPEG.
/// - [buildCameraView] retorna o widget de preview (HtmlElementView em produção).
/// - [fetchQr] busca/renova o token QR para esta sessão.
/// - [onFaceArrive] envia o frame ao backend e retorna [FaceArriveResponse].
class FaceKioskScreen extends StatefulWidget {
  final String sessionId;
  final Future<void> Function(String cameraViewId) setupCamera;
  final Future<bool> Function() detectFace;
  final Future<Uint8List?> Function() captureJpeg;
  final Widget Function(String cameraViewId) buildCameraView;
  final Future<QrTokenModel> Function() fetchQr;
  final Future<FaceArriveResponse> Function(Uint8List frame) onFaceArrive;
  /// Chamado ao retomar o quiosque após exibir resultado — retoma o vídeo congelado.
  final Future<void> Function()? resumeCamera;

  const FaceKioskScreen({
    required this.sessionId,
    required this.setupCamera,
    required this.detectFace,
    required this.captureJpeg,
    required this.buildCameraView,
    required this.fetchQr,
    required this.onFaceArrive,
    this.resumeCamera,
    super.key,
  });

  @override
  State<FaceKioskScreen> createState() => _FaceKioskScreenState();
}

// ---------------------------------------------------------------------------
// Estado interno
// ---------------------------------------------------------------------------

enum _KioskState { loading, ready, detected, sending, result, cameraError }

class _FaceKioskScreenState extends State<FaceKioskScreen> {
  final _viewId = 'kiosk-cam-${DateTime.now().microsecondsSinceEpoch}';

  _KioskState _state = _KioskState.loading;
  String _errorMsg = '';
  FaceArriveResponse? _lastResult;

  QrTokenModel? _qr;
  bool _refreshingQr = false;
  String? _qrError;

  Timer? _detectionTimer;
  Timer? _resetTimer;
  Timer? _resumeTimer;
  Timer? _qrHeartbeatTimer;

  // Cooldown por aluno — evita re-reconhecer a mesma pessoa em sequência.
  DateTime? _cooldownUntil;

  static const _qrTimeout = Duration(seconds: 10);
  static const _detectionInterval = Duration(milliseconds: 800);
  static const _resultDuration = Duration(seconds: 5);
  static const _errorDuration = Duration(seconds: 4);
  static const _resumeDelay = Duration(seconds: 3);
  static const _studentCooldown = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _resetTimer?.cancel();
    _resumeTimer?.cancel();
    _qrHeartbeatTimer?.cancel();
    super.dispose();
  }

  // ── Inicialização ─────────────────────────────────────────────────────────

  Future<void> _init() async {
    try {
      await widget.setupCamera(_viewId);
      if (!mounted) return;
      setState(() => _state = _KioskState.ready);
      _startDetectionLoop();
      unawaited(_fetchQr());
      _startQrHeartbeat();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _KioskState.cameraError;
        _errorMsg = e.toString().contains('NotAllowed') || e.toString().contains('Permission')
            ? 'Permissão de câmera negada.\nHabilite nas configurações do navegador.'
            : 'Erro ao acessar câmera.';
      });
    }
  }

  // ── Detecção ──────────────────────────────────────────────────────────────

  void _startDetectionLoop() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(_detectionInterval, (_) async {
      if (_state != _KioskState.ready) return;
      // Respeita cooldown individual do aluno recém-reconhecido.
      if (_cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!)) return;
      final found = await widget.detectFace();
      if (!found || _state != _KioskState.ready || !mounted) return;
      setState(() => _state = _KioskState.detected);
      await _captureAndSend();
    });
  }

  Future<void> _captureAndSend() async {
    _detectionTimer?.cancel();
    final bytes = await widget.captureJpeg();
    if (bytes == null || bytes.isEmpty) {
      _resetToReady();
      return;
    }

    setState(() => _state = _KioskState.sending);
    try {
      final result = await widget.onFaceArrive(bytes)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      // Registra cooldown para o aluno reconhecido (matched ou duplicate).
      if (result.matched && result.studentId != null) {
        _cooldownUntil = DateTime.now().add(_studentCooldown);
      }
      setState(() { _state = _KioskState.result; _lastResult = result; });
      _resetTimer = Timer(_resultDuration, _resetToReady);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _KioskState.result;
        _lastResult = const FaceArriveResponse(
          matched: false,
          confidence: 0,
          greeting: 'Erro ao processar. Tente novamente.',
        );
      });
      _resetTimer = Timer(_errorDuration, _resetToReady);
    }
  }

  void _resetToReady() {
    if (!mounted) return;
    setState(() => _state = _KioskState.ready);
    // Após o próximo frame (HtmlElementView de volta no DOM), retoma o vídeo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.resumeCamera?.call();
    });
    // Aguarda antes de reativar detecção para evitar re-detecção imediata.
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeDelay, () {
      if (mounted && _state == _KioskState.ready) _startDetectionLoop();
    });
  }

  // ── QR ───────────────────────────────────────────────────────────────────

  void _startQrHeartbeat() {
    _qrHeartbeatTimer?.cancel();
    _qrHeartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _refreshingQr) return;
      final q = _qr;
      if (q == null || _secondsLeft(q.expiresAt) <= 5) unawaited(_fetchQr());
    });
  }

  Future<void> _fetchQr() async {
    if (_refreshingQr) return;
    setState(() { _refreshingQr = true; _qrError = null; });
    try {
      final qr = await widget.fetchQr().timeout(_qrTimeout);
      if (!mounted) return;
      setState(() { _qr = qr; _qrError = null; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _qr = null; _qrError = 'Erro ao gerar QR.'; });
    } finally {
      if (mounted) setState(() => _refreshingQr = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Quiosque de Entrada'),
        elevation: 0,
      ),
      body: SafeArea(
        child: _state == _KioskState.cameraError
            ? _ErrorView(message: _errorMsg)
            : Stack(
                children: [
                  // A câmera permanece sempre montada: o resultado vem como
                  // overlay por cima. Se desmontássemos o HtmlElementView (ex.
                  // trocando por _ResultView), o vídeo seria desconectado do DOM
                  // e congelaria no último frame ao voltar.
                  Positioned.fill(child: _buildMain()),
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _state == _KioskState.result && _lastResult != null
                          ? _ResultView(
                              key: const ValueKey('result'),
                              result: _lastResult!,
                            )
                          : const SizedBox.shrink(key: ValueKey('empty')),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMain() {
    return LayoutBuilder(
      key: const ValueKey('main'),
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight;
        return landscape
            ? Row(children: [
                Expanded(child: _buildCameraColumn()),
                Container(width: 1, color: Colors.white12),
                SizedBox(width: 260, child: _buildQrSection()),
              ])
            : Column(children: [
                Expanded(flex: 3, child: _buildCameraColumn()),
                Container(height: 1, color: Colors.white12),
                SizedBox(height: 210, child: _buildQrSection()),
              ]);
      },
    );
  }

  Widget _buildCameraColumn() {
    return Column(children: [
      Expanded(
        child: _state == _KioskState.loading
            ? const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Iniciando câmera…', style: TextStyle(color: Colors.white60)),
                ]),
              )
            : widget.buildCameraView(_viewId),
      ),
      _buildStatusBar(),
    ]);
  }

  Widget _buildStatusBar() {
    final (icon, text, color) = switch (_state) {
      _KioskState.loading  => (Icons.hourglass_empty,        'Iniciando…',                        Colors.white38),
      _KioskState.ready    => (Icons.face_outlined,           'Posicione-se em frente à câmera',   Colors.white70),
      _KioskState.detected => (Icons.face_retouching_natural, 'Rosto detectado! Aguarde…',         Colors.greenAccent),
      _KioskState.sending  => (Icons.cloud_upload_outlined,   'Identificando…',                    Colors.lightBlueAccent),
      _                    => (Icons.face_outlined,           '',                                  Colors.white38),
    };

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: TextStyle(color: color, fontSize: 14))),
        if (_state == _KioskState.sending) ...[
          const SizedBox(width: 12),
          const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
          ),
        ],
      ]),
    );
  }

  Widget _buildQrSection() {
    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text(
          'Ou escaneie pelo celular',
          style: TextStyle(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (_qr != null) ...[
          RepaintBoundary(
            child: QrImageView(
              key: ValueKey(_qr!.token),
              data: _qr!.token,
              size: 150,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 8),
          _QrCountdown(
            key: ValueKey(_qr!.token),
            expiresAt: _qr!.expiresAt,
            textStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ] else if (_refreshingQr)
          const SizedBox(
            width: 28, height: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
          )
        else if (_qrError != null)
          Text(_qrError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center)
        else
          const Text('Gerando QR…', style: TextStyle(color: Colors.white38, fontSize: 12)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Tela de resultado
// ---------------------------------------------------------------------------

class _ResultView extends StatelessWidget {
  final FaceArriveResponse result;
  const _ResultView({required this.result, super.key});

  @override
  Widget build(BuildContext context) {
    final color = result.matched
        ? (result.wasPunctual == false ? Colors.orange.shade800 : Colors.green.shade700)
        : Colors.red.shade800;
    final icon = result.matched
        ? (result.wasPunctual == false ? Icons.timer_off_outlined : Icons.check_circle_outline)
        : Icons.help_outline;

    return Container(
      color: color,
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 80, color: Colors.white),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            result.greeting,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        if (result.matched && result.xpAwarded > 0) ...[
          const SizedBox(height: 16),
          Text('+${result.xpAwarded} XP',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
        ],
        if (result.matched && (result.punctualityStreak ?? 0) > 1) ...[
          const SizedBox(height: 8),
          Text('🔥 ${result.punctualityStreak} treinos pontuais seguidos',
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ],
        const SizedBox(height: 40),
        const Text('Voltando em instantes…',
            style: TextStyle(color: Colors.white54, fontSize: 14)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Tela de erro de câmera
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.videocam_off_outlined, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: Colors.white60, fontSize: 16),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Countdown QR
// ---------------------------------------------------------------------------

class _QrCountdown extends StatefulWidget {
  final DateTime expiresAt;
  final TextStyle? textStyle;
  const _QrCountdown({required this.expiresAt, this.textStyle, super.key});

  @override
  State<_QrCountdown> createState() => _QrCountdownState();
}

class _QrCountdownState extends State<_QrCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

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
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}
