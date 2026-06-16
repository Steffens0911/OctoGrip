import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:viewer/screens/student/user_facial_photo_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Tela "Privacidade e meus dados" — direitos do titular (LGPD):
/// ver consentimentos, abrir documentos legais, revogar biometria,
/// baixar os próprios dados e excluir a conta.
class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key});

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  final _api = ApiService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _consents = const [];
  bool _busy = false;

  static const _labels = {
    'terms': 'Termos de Uso',
    'privacy': 'Política de Privacidade',
    'biometric': 'Reconhecimento facial (biometria)',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getMyConsents();
      if (!mounted) return;
      setState(() {
        _consents = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingMessage(e);
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? _consent(String type) {
    for (final c in _consents) {
      if (c['consent_type'] == type) return c;
    }
    return null;
  }

  Future<void> _openLegalDoc(String slug) async {
    final uri = Uri.parse(_api.legalDocumentViewUrl(slug));
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        AppFeedback.show(context, message: 'Não foi possível abrir o documento.', type: AppFeedbackType.error);
      }
    } catch (e) {
      if (mounted) AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _grantBiometric() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ativar reconhecimento facial'),
        content: const Text(
          'Sua foto facial será usada exclusivamente para registrar presença nas aulas. '
          'O uso é opcional e você pode revogar este consentimento a qualquer momento, '
          'apagando todos os seus dados biométricos.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ativar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _api.recordConsent(consentType: 'biometric');
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserFacialPhotoScreen()),
      );
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeBiometric() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revogar reconhecimento facial'),
        content: const Text(
          'Sua foto facial e os dados biométricos serão apagados imediatamente. '
          'Você poderá continuar registrando presença por QR Code.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Revogar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _api.revokeBiometricConsent();
      await AuthService().refreshMe();
      if (!mounted) return;
      AppFeedback.show(context, message: 'Reconhecimento facial revogado e dados apagados.', type: AppFeedbackType.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportData() async {
    setState(() => _busy = true);
    try {
      final data = await _api.exportMyData();
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Meus dados'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(pretty, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: pretty));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  AppFeedback.show(context, message: 'Dados copiados.', type: AppFeedbackType.success);
                }
              },
              child: const Text('Copiar'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir minha conta'),
        content: const Text(
          'Esta ação é irreversível. Seus dados pessoais (nome, e-mail, foto e biometria) '
          'serão removidos e você perderá o acesso ao aplicativo.\n\nDeseja continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir conta'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _api.deleteMyAccount();
      await AuthService().logout();
      if (!mounted) return;
      AppFeedback.show(context, message: 'Conta excluída. Seus dados foram removidos.', type: AppFeedbackType.success);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Privacidade e meus dados'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(context),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Erro ao carregar.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
            ],
          ),
        ),
      );

  Widget _buildContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final biometric = _consent('biometric');
    final biometricGranted = biometric?['granted'] == true;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Documentos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _docTile('Política de Privacidade', 'privacy'),
        _docTile('Termos de Uso', 'terms'),
        _docTile('Aviso de biometria', 'biometric'),
        const SizedBox(height: 24),

        Text('Meus consentimentos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final type in const ['terms', 'privacy', 'biometric']) _consentStatusTile(type),
        const SizedBox(height: 24),

        Text('Reconhecimento facial', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (biometricGranted)
          Card(
            child: ListTile(
              leading: Icon(Icons.no_photography_outlined, color: cs.error),
              title: const Text('Revogar reconhecimento facial'),
              subtitle: const Text('Apaga sua foto facial e os dados biométricos.'),
              onTap: _busy ? null : _revokeBiometric,
            ),
          )
        else ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Reconhecimento facial não ativado'),
              subtitle: const Text('Você registra presença por QR Code.'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _grantBiometric,
            icon: const Icon(Icons.face_retouching_natural_outlined),
            label: const Text('Ativar reconhecimento facial'),
          ),
        ],
        const SizedBox(height: 24),

        Text('Meus dados', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Baixar meus dados'),
            subtitle: const Text('Uma cópia dos seus dados pessoais.'),
            onTap: _busy ? null : _exportData,
          ),
        ),
        const SizedBox(height: 24),

        Text('Zona de risco', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.error)),
        const SizedBox(height: 8),
        Card(
          color: cs.errorContainer.withValues(alpha: 0.3),
          child: ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: cs.error),
            title: const Text('Excluir minha conta'),
            subtitle: const Text('Remove seus dados pessoais. Irreversível.'),
            onTap: _busy ? null : _deleteAccount,
          ),
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Widget _docTile(String title, String slug) => Card(
        child: ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(title),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _openLegalDoc(slug),
        ),
      );

  Widget _consentStatusTile(String type) {
    final c = _consent(type);
    final granted = c?['granted'] == true;
    final upToDate = c?['up_to_date'] == true;
    final cs = Theme.of(context).colorScheme;
    final (IconData icon, Color color, String status) = granted
        ? (upToDate
            ? (Icons.check_circle, Colors.green, 'Aceito')
            : (Icons.update, Colors.orange, 'Aceito (versão anterior)'))
        : (Icons.cancel_outlined, cs.onSurfaceVariant, 'Não aceito');
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Text(_labels[type] ?? type),
      trailing: Text(status, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
