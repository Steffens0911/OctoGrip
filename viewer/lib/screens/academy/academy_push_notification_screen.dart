import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Permite ao gerente/professor (escrita na academia) enviar um aviso push
/// a todos os utilizadores da mesma academia com token FCM registado.
class AcademyPushNotificationScreen extends StatefulWidget {
  const AcademyPushNotificationScreen({super.key});

  @override
  State<AcademyPushNotificationScreen> createState() =>
      _AcademyPushNotificationScreenState();
}

class _AcademyPushNotificationScreenState
    extends State<AcademyPushNotificationScreen> {
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

  Future<void> _send() async {
    final academyId = AuthService().currentUser?.academyId;
    if (academyId == null || academyId.isEmpty) {
      setState(() => _error = 'Seu usuário não está vinculado a uma academia.');
      return;
    }
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = 'Preencha título e mensagem.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final r = await _api.sendAcademyPushNotification(
        academyId,
        title: title,
        body: body,
      );
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
    return Scaffold(
      appBar: const AppStandardAppBar(
        title: 'Aviso à academia',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'A mensagem aparece na barra de notificações dos alunos e equipa '
              'que tenham o app no telemóvel, com conta na sua academia e '
              'notificações ativas.',
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
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_sending ? 'Enviando…' : 'Enviar notificação'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
