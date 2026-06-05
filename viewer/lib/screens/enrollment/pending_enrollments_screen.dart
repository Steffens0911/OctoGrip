import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:flutter/foundation.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart' show userFacingMessage;

const _beltLabels = {
  'white': 'Branca',
  'blue': 'Azul',
  'purple': 'Roxa',
  'brown': 'Marrom',
  'black': 'Preta',
};

/// Tela do gestor: mostra QR/link de convite e lista de solicitações pendentes.
class PendingEnrollmentsScreen extends StatefulWidget {
  final String academyId;
  final String academyName;

  const PendingEnrollmentsScreen({
    super.key,
    required this.academyId,
    required this.academyName,
  });

  @override
  State<PendingEnrollmentsScreen> createState() =>
      _PendingEnrollmentsScreenState();
}

class _PendingEnrollmentsScreenState extends State<PendingEnrollmentsScreen> {
  final _api = ApiService();

  String? _token;
  List<Map<String, dynamic>> _pending = [];
  bool _loadingInvite = true;
  bool _loadingList = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadInvite(), _loadPending()]);
  }

  Future<void> _loadInvite() async {
    try {
      final data = await _api.getEnrollmentInvite(widget.academyId);
      if (mounted) {
        setState(() {
          _token = data['token'] as String?;
          _loadingInvite = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(e);
          _loadingInvite = false;
        });
      }
    }
  }

  Future<void> _loadPending() async {
    try {
      final list = await _api.getPendingEnrollments(widget.academyId);
      if (mounted) {
        setState(() {
          _pending = list;
          _loadingList = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _rotateInvite() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gerar novo link?'),
        content: const Text(
            'O link atual será invalidado. Quem recebeu o link antigo não conseguirá mais se cadastrar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gerar novo')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final data = await _api.rotateEnrollmentInvite(widget.academyId);
      if (mounted) setState(() => _token = data['token'] as String?);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  Future<void> _decide(Map<String, dynamic> enrollment, String action) async {
    String? reason;
    if (action == 'reject') {
      reason = await _askRejectionReason();
      if (reason == null) return;
    }

    try {
      await _api.decideEnrollment(
        widget.academyId,
        enrollment['id'] as String,
        action: action,
        rejectionReason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'approve'
                ? '${enrollment['name']} aprovado!'
                : 'Solicitação rejeitada.'),
          ),
        );
        setState(() => _pending.remove(enrollment));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  Future<String?> _askRejectionReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo da rejeição (opcional)'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Ex.: aluno já cadastrado'),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Rejeitar')),
        ],
      ),
    );
  }

  String get _inviteUrl {
    if (kIsWeb) {
      final base = Uri.base.origin;
      return '$base/?register=$_token';
    }
    return '/?register=$_token';
  }

  void _copyLink() {
    if (_token == null) return;
    Clipboard.setData(ClipboardData(text: _inviteUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiado!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cadastros — ${widget.academyName}'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInviteCard(cs),
            const SizedBox(height: 24),
            _buildPendingList(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Link de convite',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Compartilhe este QR code ou link para alunos se cadastrarem.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (_loadingInvite)
              const Center(child: CircularProgressIndicator())
            else if (_token != null) ...[
              Center(
                child: QrImageView(
                  data: _inviteUrl,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _inviteUrl,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: _copyLink,
                      tooltip: 'Copiar link',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Gerar novo link'),
                onPressed: _rotateInvite,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pending_actions, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Solicitações pendentes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_pending.isNotEmpty) ...[
              const SizedBox(width: 8),
              Badge(
                label: Text('${_pending.length}'),
                backgroundColor: cs.primary,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingList)
          const Center(child: CircularProgressIndicator())
        else if (_pending.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Nenhuma solicitação pendente.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else
          ...(_pending.map((e) => _buildEnrollmentCard(e, cs))),
      ],
    );
  }

  Widget _buildEnrollmentCard(Map<String, dynamic> e, ColorScheme cs) {
    final belt = e['graduation'] as String?;
    final beltLabel = belt != null ? (_beltLabels[belt] ?? belt) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    (e['name'] as String? ?? '?')[0].toUpperCase(),
                    style: TextStyle(color: cs.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e['name'] as String? ?? '',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        e['email'] as String? ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (e['phone'] != null || beltLabel != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (e['phone'] != null)
                    Chip(
                      label: Text(e['phone'] as String),
                      avatar: const Icon(Icons.phone, size: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (beltLabel != null)
                    Chip(
                      label: Text('Faixa $beltLabel'),
                      avatar: const Icon(Icons.emoji_events, size: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Rejeitar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error),
                  ),
                  onPressed: () => _decide(e, 'reject'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Aprovar'),
                  onPressed: () => _decide(e, 'approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
