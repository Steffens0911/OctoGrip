import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:viewer/services/pwa_install_service.dart';

/// Banner discreto que aparece no rodapé da tela sugerindo a instalação do app.
///
/// - Android Chrome/Edge: dispara o prompt nativo ao tocar em "Instalar".
/// - iOS Safari: abre um diálogo explicando os passos manuais.
/// - Já instalado como PWA: não exibe nada.
class PwaInstallBanner extends StatefulWidget {
  final Widget child;

  const PwaInstallBanner({super.key, required this.child});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  bool _dismissed = false;
  bool _installed = false;
  // Se true, o browser é iOS Safari (sem prompt nativo — mostra guia manual).
  bool _isIosBrowser = false;

  @override
  void initState() {
    super.initState();
    _checkInstalled();
  }

  Future<void> _checkInstalled() async {
    if (!kIsWeb) return;
    // Pequeno delay para o JS ter tempo de registrar o evento beforeinstallprompt.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    if (PwaInstallService.instance.isInstalled) {
      setState(() => _installed = true);
      return;
    }
    setState(() {});
  }

  bool get _shouldShow {
    if (!kIsWeb) return false;
    if (_dismissed || _installed) return false;
    if (PwaInstallService.instance.isInstalled) return false;
    return PwaInstallService.instance.canInstallNatively || _isIosBrowser;
  }

  void _onInstall() {
    if (PwaInstallService.instance.canInstallNatively) {
      PwaInstallService.instance.triggerInstall();
      setState(() => _dismissed = true);
    } else {
      _showIosGuide();
    }
  }

  void _showIosGuide() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.ios_share_rounded, size: 28),
                const SizedBox(width: 12),
                Text('Instalar no iPhone / iPad',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
              ],
            ),
            const SizedBox(height: 16),
            _Step(
                number: '1',
                text: 'Toque no botão Compartilhar',
                icon: Icons.ios_share_rounded),
            const SizedBox(height: 10),
            _Step(
                number: '2',
                text: 'Role para baixo e toque em "Adicionar à Tela de Início"',
                icon: Icons.add_box_outlined),
            const SizedBox(height: 10),
            _Step(
                number: '3',
                text: 'Toque em "Adicionar" no canto superior direito',
                icon: Icons.check_circle_outline_rounded),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: _InstallBar(
              onInstall: _onInstall,
              onDismiss: () => setState(() => _dismissed = true),
            ),
          ),
        ),
      ],
    );
  }
}

class _InstallBar extends StatelessWidget {
  final VoidCallback onInstall;
  final VoidCallback onDismiss;

  const _InstallBar({required this.onInstall, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.install_mobile_rounded, color: cs.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Instale o app para acesso rápido',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                foregroundColor: cs.onPrimaryContainer.withValues(alpha: 0.7),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Agora não'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: onInstall,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Instalar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;
  final IconData icon;

  const _Step(
      {required this.number, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(number,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}
