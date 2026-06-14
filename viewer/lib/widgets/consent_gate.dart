import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';

/// Gate de consentimento pós-login (LGPD).
///
/// Antes de liberar o app, verifica se o utilizador já aceitou Termos de Uso e
/// Política de Privacidade na versão vigente. Se não, mostra uma tela bloqueante
/// de aceite. Em caso de erro de rede/API, **falha aberto** (mostra o app) para
/// não tornar o aplicativo inutilizável quando o backend estiver indisponível.
class ConsentGate extends StatefulWidget {
  final Widget child;

  const ConsentGate({super.key, required this.child});

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  final _api = ApiService();

  bool _loading = true;
  bool _needsConsent = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final items = await _api.getMyConsents();
      bool pending(String type) {
        final c = items.firstWhere(
          (e) => e['consent_type'] == type,
          orElse: () => const {'up_to_date': false},
        );
        return c['up_to_date'] != true;
      }

      final needs = pending('terms') || pending('privacy');
      if (!mounted) return;
      setState(() {
        _needsConsent = needs;
        _loading = false;
      });
    } catch (_) {
      // Falha aberto: não bloquear o app por indisponibilidade do backend.
      if (!mounted) return;
      setState(() {
        _needsConsent = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_needsConsent) {
      return _ConsentRequiredView(onAccepted: () => setState(() => _needsConsent = false));
    }
    return widget.child;
  }
}

class _ConsentRequiredView extends StatefulWidget {
  final VoidCallback onAccepted;

  const _ConsentRequiredView({required this.onAccepted});

  @override
  State<_ConsentRequiredView> createState() => _ConsentRequiredViewState();
}

class _ConsentRequiredViewState extends State<_ConsentRequiredView> {
  final _api = ApiService();
  bool _accept = false;
  bool _submitting = false;

  Future<void> _openLegal(String slug) async {
    final uri = Uri.parse(_api.legalDocumentViewUrl(slug));
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _submit() async {
    if (!_accept || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _api.recordConsent(consentType: 'terms');
      await _api.recordConsent(consentType: 'privacy');
      if (!mounted) return;
      widget.onAccepted();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.privacy_tip_outlined, size: 56, color: cs.primary),
                  const SizedBox(height: 16),
                  Text('Antes de continuar', style: tt.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text(
                    'Atualizamos nossos termos. Para continuar usando o app, é preciso ler e '
                    'aceitar os documentos abaixo.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => _openLegal('terms'),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Ler os Termos de Uso'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openLegal('privacy'),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Ler a Política de Privacidade'),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _accept,
                    onChanged: (v) => setState(() => _accept = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Li e aceito os Termos de Uso e a Política de Privacidade.'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: (!_accept || _submitting) ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Aceitar e continuar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _submitting ? null : () => AuthService().logout(),
                    child: const Text('Sair'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
