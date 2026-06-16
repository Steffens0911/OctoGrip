import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:viewer/screens/student/user_facial_photo_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';

/// Gate de consentimento pós-login (LGPD).
///
/// Passo 1 (bloqueante): Termos de Uso + Política de Privacidade.
/// Passo 2 (opcional):   Consentimento biométrico — usuário pode pular.
/// Em caso de erro de rede/API, **falha aberto** (mostra o app).
class ConsentGate extends StatefulWidget {
  final Widget child;

  /// Injetado apenas em testes — em produção usa o singleton [ApiService()].
  @visibleForTesting
  final ApiService? testApiService;

  const ConsentGate({super.key, required this.child, this.testApiService});

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  late final ApiService _api;

  bool _loading = true;
  bool _needsTerms = false;
  bool _needsBiometric = false;

  @override
  void initState() {
    super.initState();
    _api = widget.testApiService ?? ApiService();
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

      bool notGranted(String type) {
        final c = items.firstWhere(
          (e) => e['consent_type'] == type,
          orElse: () => const {'granted': false},
        );
        return c['granted'] != true;
      }

      if (!mounted) return;
      setState(() {
        _needsTerms = pending('terms') || pending('privacy');
        _needsBiometric = !_needsTerms && notGranted('biometric');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _needsTerms = false;
        _needsBiometric = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_needsTerms) {
      return _ConsentRequiredView(
        api: _api,
        onAccepted: () {
          setState(() {
            _needsTerms = false;
            _needsBiometric = true;
          });
        },
      );
    }
    if (_needsBiometric) {
      return _BiometricConsentView(
        api: _api,
        onDone: () => setState(() => _needsBiometric = false),
      );
    }
    return widget.child;
  }
}

// ---------------------------------------------------------------------------
// Passo 1 — Termos + Privacidade (bloqueante)
// ---------------------------------------------------------------------------

class _ConsentRequiredView extends StatefulWidget {
  final ApiService api;
  final VoidCallback onAccepted;

  const _ConsentRequiredView({required this.api, required this.onAccepted});

  @override
  State<_ConsentRequiredView> createState() => _ConsentRequiredViewState();
}

class _ConsentRequiredViewState extends State<_ConsentRequiredView> {
  ApiService get _api => widget.api;
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

// ---------------------------------------------------------------------------
// Passo 2 — Biometria (opcional)
// ---------------------------------------------------------------------------

class _BiometricConsentView extends StatefulWidget {
  final ApiService api;
  final VoidCallback onDone;

  const _BiometricConsentView({required this.api, required this.onDone});

  @override
  State<_BiometricConsentView> createState() => _BiometricConsentViewState();
}

class _BiometricConsentViewState extends State<_BiometricConsentView> {
  ApiService get _api => widget.api;
  bool _submitting = false;

  Future<void> _openBiometricNotice() async {
    final uri = Uri.parse(_api.legalDocumentViewUrl('biometric'));
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _accept() async {
    setState(() => _submitting = true);
    try {
      await _api.recordConsent(consentType: 'biometric');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserFacialPhotoScreen()),
      );
      if (!mounted) return;
      widget.onDone();
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
                  Icon(Icons.face_retouching_natural_outlined, size: 56, color: cs.primary),
                  const SizedBox(height: 16),
                  Text('Reconhecimento facial', style: tt.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Opcional — você pode pular',
                      textAlign: TextAlign.center,
                      style: tt.labelMedium?.copyWith(color: cs.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Quer usar o reconhecimento facial para registrar presença nas aulas? '
                    'Precisamos do seu consentimento para tratar sua foto facial.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'É sempre opcional: você pode usar QR Code e revogar este consentimento '
                    'a qualquer momento em Privacidade → Reconhecimento facial.',
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _openBiometricNotice,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Ler o aviso completo de biometria'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _accept,
                    icon: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Ativar reconhecimento facial'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _submitting ? null : widget.onDone,
                    child: const Text('Agora não, usar QR Code'),
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
