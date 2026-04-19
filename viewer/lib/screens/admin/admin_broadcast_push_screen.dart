import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';
import 'package:viewer/widgets/role_guard.dart';

/// Administrador global: envia push FCM a **todos** os tokens registados na API.
class AdminBroadcastPushScreen extends StatefulWidget {
  const AdminBroadcastPushScreen({super.key});

  @override
  State<AdminBroadcastPushScreen> createState() =>
      _AdminBroadcastPushScreenState();
}

class _AdminBroadcastPushScreenState extends State<AdminBroadcastPushScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _api = ApiService();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSend() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = 'Preencha título e mensagem.');
      return;
    }
    setState(() => _error = null);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar para toda a plataforma?'),
        content: const Text(
          'Esta mensagem será enviada a todos os dispositivos com o app e '
          'notificações ativas (qualquer academia). Só use para avisos '
          'realmente globais.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final r = await _api.sendAdminPushBroadcast(title: title, body: body);
      if (!mounted) return;
      AppFeedback.show(
        context,
        message:
            'Enviado: ${r.sent} de ${r.targetTokens} dispositivos (${r.failed} falhas).',
        type: r.sent > 0 ? AppFeedbackType.success : AppFeedbackType.info,
      );
      _titleCtrl.clear();
      _bodyCtrl.clear();
    } catch (e) {
      if (mounted) {
        setState(() => _error = userFacingMessage(e));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['administrador'],
      child: Scaffold(
        appBar: const AppStandardAppBar(
          title: 'Push global',
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Envia uma notificação na barra do sistema para todos os '
                'utilizadores que tenham sessão na app móvel e token FCM '
                'registado (todas as academias).',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bodyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mensagem',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _sending ? null : _confirmAndSend,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.campaign_rounded),
                label: Text(_sending ? 'Enviando…' : 'Rever e enviar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
