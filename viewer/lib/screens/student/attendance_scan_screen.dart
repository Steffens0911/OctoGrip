import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:viewer/config.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/network_diagnostics_service.dart';
import 'package:viewer/screens/debug/network_diagnostics_screen.dart';
import 'package:viewer/utils/api_base_persist.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class AttendanceScanScreen extends StatefulWidget {
  const AttendanceScanScreen({super.key});

  @override
  State<AttendanceScanScreen> createState() => _AttendanceScanScreenState();
}

class _AttendanceScanScreenState extends State<AttendanceScanScreen> {
  final _api = ApiService();
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final _apiTunnelController = TextEditingController();

  bool _busy = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _apiTunnelController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitPayload(String payload) async {
    final p = payload.trim();
    if (p.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await _api.scanAttendance(p);
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: 'Presença confirmada',
        type: AppFeedbackType.success,
      );
      Navigator.pop(context);
    } catch (e, st) {
      NetworkDiagnosticsService.recordError(
        e,
        stackTrace: st,
        context: 'Escanear QR da chamada',
      );
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
      setState(() => _busy = false);
    }
  }

  Future<void> _openManualEntry() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inserir código'),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Código do QR',
            hintText: 'Cole o payload (sid=...&iat=...&exp=...&nonce=...&sig=...)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    final payload = c.text;
    c.dispose();
    if (ok == true) {
      await _submitPayload(payload);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Web em túnel público sem api_base: evita erro opaco ao chamar API (kApiBaseUrl vazio).
    if (kIsWeb && kApiBaseUrl.isEmpty) {
      return Scaffold(
        appBar: const AppStandardAppBar(title: 'Escanear QR da chamada'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const AppErrorMessage(message: kWebTrycloudflareMissingApiBaseMessage),
              const SizedBox(height: 20),
              TextField(
                controller: _apiTunnelController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'URL do túnel da API',
                  hintText: 'https://….trycloudflare.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () {
                  final u = _apiTunnelController.text.trim();
                  if (u.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cole a URL do túnel da API.')),
                    );
                    return;
                  }
                  if (!u.startsWith('https://') && !u.startsWith('http://')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('A URL deve começar com https:// ou http://'),
                      ),
                    );
                    return;
                  }
                  persistApiBaseAndReload(u);
                },
                child: const Text('Salvar URL da API e recarregar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppStandardAppBar(
        title: 'Escanear QR da chamada',
        actions: [
          IconButton(
            tooltip: 'Diagnóstico',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NetworkDiagnosticsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.health_and_safety_rounded),
          ),
          IconButton(
            tooltip: 'Inserir código',
            onPressed: _busy ? null : _openManualEntry,
            icon: const Icon(Icons.keyboard_rounded),
          ),
          IconButton(
            tooltip: _torchOn ? 'Desligar lanterna' : 'Ligar lanterna',
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
            icon: Icon(_torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final raw = barcodes.first.rawValue;
              if (raw == null || raw.trim().isEmpty) return;
              _submitPayload(raw);
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _busy
                            ? 'Confirmando presença...'
                            : 'Aponte a câmera para o QR exibido pelo professor.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

