import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:viewer/models/face_checkin.dart';

/// Tela quiosque de reconhecimento facial por chegada.
///
/// [captureFrame] captura um frame da câmera e retorna os bytes JPEG.
/// Em produção: usa image_picker com ImageSource.camera.
/// Em testes: injeta um mock que retorna bytes fixos.
///
/// [onFaceArrive] envia o frame ao backend e retorna [FaceArriveResponse].
/// Em produção: chama ApiService().faceArrive().
/// Em testes: injeta um mock.
class FaceKioskScreen extends StatefulWidget {
  final String sessionId;
  final Future<Uint8List?> Function() captureFrame;
  final Future<FaceArriveResponse> Function(Uint8List frame) onFaceArrive;

  const FaceKioskScreen({
    required this.sessionId,
    required this.captureFrame,
    required this.onFaceArrive,
    super.key,
  });

  @override
  State<FaceKioskScreen> createState() => _FaceKioskScreenState();
}

enum _KioskState { waiting, capturing, result }

class _FaceKioskScreenState extends State<FaceKioskScreen> {
  _KioskState _state = _KioskState.waiting;
  FaceArriveResponse? _lastResult;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _onCapture() async {
    if (_state != _KioskState.waiting) return;

    setState(() => _state = _KioskState.capturing);

    try {
      final bytes = await widget.captureFrame();
      if (bytes == null || bytes.isEmpty) {
        if (mounted) setState(() => _state = _KioskState.waiting);
        return;
      }

      final result = await widget.onFaceArrive(bytes);
      if (!mounted) return;

      setState(() {
        _state = _KioskState.result;
        _lastResult = result;
      });

      // Volta ao estado de espera após 5 s
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _state = _KioskState.waiting);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _state = _KioskState.result;
          _lastResult = const FaceArriveResponse(
            matched: false,
            confidence: 0,
            greeting: 'Erro ao processar. Tente novamente.',
          );
        });
        _resetTimer?.cancel();
        _resetTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _state = _KioskState.waiting);
        });
      }
    }
  }

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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (_state) {
            _KioskState.waiting => _WaitingView(onCapture: _onCapture),
            _KioskState.capturing => const _CapturingView(),
            _KioskState.result => _ResultView(result: _lastResult!),
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-views
// ---------------------------------------------------------------------------

class _WaitingView extends StatelessWidget {
  final VoidCallback onCapture;

  const _WaitingView({required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('waiting'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.face_outlined, size: 96, color: Colors.white70),
          const SizedBox(height: 24),
          Text(
            'Posicione-se em frente à câmera',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: onCapture,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Identificar'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(200, 56),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapturingView extends StatelessWidget {
  const _CapturingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('capturing'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 24),
          Text(
            'Identificando…',
            style: TextStyle(color: Colors.white70, fontSize: 20),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final FaceArriveResponse result;

  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.matched
        ? (result.wasPunctual == false ? Colors.orange.shade800 : Colors.green.shade700)
        : Colors.red.shade800;

    final icon = result.matched
        ? (result.wasPunctual == false ? Icons.timer_off_outlined : Icons.check_circle_outline)
        : Icons.help_outline;

    return Container(
      key: const ValueKey('result'),
      color: color,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.white),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              result.greeting,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (result.matched && result.xpAwarded > 0) ...[
            const SizedBox(height: 16),
            Text(
              '+${result.xpAwarded} XP',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (result.matched && (result.punctualityStreak ?? 0) > 1) ...[
            const SizedBox(height: 8),
            Text(
              '🔥 ${result.punctualityStreak} treinos pontuais seguidos',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
          const SizedBox(height: 40),
          const Text(
            'Voltando em instantes…',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
