import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
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

  bool _busy = false;
  bool _torchOn = false;

  @override
  void dispose() {
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
    } catch (e) {
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
    return Scaffold(
      appBar: AppStandardAppBar(
        title: 'Escanear QR da chamada',
        actions: [
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

