import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/services/api_service.dart';

/// Lista de execuções pendentes de confirmação (o usuário é o adversário).
class PendingConfirmationsScreen extends StatefulWidget {
  final String userId;
  final String? userName;

  const PendingConfirmationsScreen({super.key, required this.userId, this.userName});

  @override
  State<PendingConfirmationsScreen> createState() => _PendingConfirmationsScreenState();
}

class _PendingConfirmationsScreenState extends State<PendingConfirmationsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getPendingConfirmations(widget.userId);
      if (mounted) setState(() { _list = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _confirm(String executionId, String outcome) async {
    try {
      await _api.postExecutionConfirm(
        executionId: executionId,
        outcome: outcome,
        userId: widget.userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirmação registrada!'), backgroundColor: AppTheme.primary),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _rejectDontRemember(String executionId) async {
    try {
      await _api.postExecutionReject(
        executionId: executionId,
        userId: widget.userId,
        reason: 'dont_remember',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O colega foi notificado de que você não confirmou.'),
          backgroundColor: AppTheme.primary,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Confirmações pendentes'),
            if (widget.userName != null && widget.userName!.isNotEmpty)
              Text(
                'Para: ${widget.userName!}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
                      ],
                    ),
                  ),
                )
              : _list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Nenhuma confirmação pendente.',
                              style: TextStyle(color: AppTheme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'As solicitações aparecem aqui quando alguém indicar você como adversário. '
                              'Certifique-se de estar com seu usuário selecionado no início da página (Área do aluno).',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _list.length,
                        itemBuilder: (context, i) {
                          final e = _list[i];
                          final id = e['id'] as String?;
                          final executorName = e['executor_name'] as String? ?? 'Alguém';
                          final techniqueName = e['technique_name'] as String? ?? 'a técnica';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '$executorName disse que aplicou $techniqueName em você.',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: id == null ? null : () => _rejectDontRemember(id),
                                        child: Text('Não lembro', style: TextStyle(color: Colors.grey.shade700)),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: id == null ? null : () => _confirm(id, 'attempted_correctly'),
                                        child: const Text('Tentativa correta'),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        onPressed: id == null ? null : () => _confirm(id, 'executed_successfully'),
                                        child: const Text('Executou com sucesso'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
