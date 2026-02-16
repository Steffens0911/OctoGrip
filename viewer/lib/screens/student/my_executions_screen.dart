import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/services/api_service.dart';

/// Lista de execuções criadas pelo usuário (executor). Mostra status e mensagem quando o adversário não aceitou.
class MyExecutionsScreen extends StatefulWidget {
  final String userId;

  const MyExecutionsScreen({super.key, required this.userId});

  @override
  State<MyExecutionsScreen> createState() => _MyExecutionsScreenState();
}

class _MyExecutionsScreenState extends State<MyExecutionsScreen> {
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
      final list = await _api.getMyExecutions(widget.userId);
      if (mounted) setState(() { _list = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  static String _statusLabel(String? status) {
    switch (status) {
      case 'pending_confirmation':
        return 'Aguardando confirmação';
      case 'confirmed':
        return 'Confirmado';
      case 'rejected':
        return 'Recusado';
      case 'rejected_dont_remember':
        return 'Não aceitou';
      default:
        return status ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas solicitações'),
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
                      child: Text(
                        'Nenhuma solicitação de confirmação.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _list.length,
                        itemBuilder: (context, i) {
                          final e = _list[i];
                          final status = e['status'] as String?;
                          final techniqueName = e['technique_name'] as String? ?? 'técnica';
                          final opponentName = e['opponent_name'] as String? ?? 'Colega';
                          final isRejectedDontRemember = status == 'rejected_dont_remember';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    techniqueName,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Em $opponentName',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isRejectedDontRemember
                                              ? Colors.orange.shade100
                                              : status == 'confirmed'
                                                  ? Colors.green.shade100
                                                  : status == 'pending_confirmation'
                                                      ? Colors.blue.shade100
                                                      : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isRejectedDontRemember
                                                ? Colors.orange.shade900
                                                : status == 'confirmed'
                                                    ? Colors.green.shade900
                                                    : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isRejectedDontRemember) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '$opponentName não aceitou a posição atribuída a você.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.orange.shade800,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
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
