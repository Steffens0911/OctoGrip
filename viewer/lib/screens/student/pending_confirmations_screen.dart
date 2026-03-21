import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

/// Lista de execuções pendentes de confirmação (o usuário é o adversário).
class PendingConfirmationsScreen extends StatefulWidget {
  final String userId;
  final String? userName;

  const PendingConfirmationsScreen(
      {super.key, required this.userId, this.userName});

  @override
  State<PendingConfirmationsScreen> createState() =>
      _PendingConfirmationsScreenState();
}

class _PendingConfirmationsScreenState
    extends State<PendingConfirmationsScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _loading = true;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    var filtered = _allItems;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((e) {
        final executorName =
            (e['executor_name'] as String? ?? '').toLowerCase();
        final techniqueName =
            (e['technique_name'] as String? ?? '').toLowerCase();
        return executorName.contains(query) || techniqueName.contains(query);
      }).toList();
    }
    setState(() => _filteredItems = filtered);
  }

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
      final list = await _api.getPendingConfirmations();
      if (mounted)
        setState(() {
          _allItems = list;
          _loading = false;
        });
      _applyFilters();
    } catch (e) {
      if (mounted)
        setState(() {
          _error = userFacingMessage(e);
          _loading = false;
        });
    }
  }

  Future<void> _confirm(String executionId, String outcome) async {
    try {
      await _api.postExecutionConfirm(
        executionId: executionId,
        outcome: outcome,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Confirmação registrada!'),
            backgroundColor: AppTheme.primary),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(userFacingMessage(e)),
            backgroundColor: Colors.red.shade700),
      );
    }
  }

  static String _faixaLabel(String? g) {
    if (g == null || g.isEmpty) return '';
    switch (g.toLowerCase()) {
      case 'white':
        return 'Branca';
      case 'blue':
        return 'Azul';
      case 'purple':
        return 'Roxa';
      case 'brown':
        return 'Marrom';
      case 'black':
        return 'Preta';
      default:
        return g;
    }
  }

  Future<void> _rejectDontRemember(String executionId) async {
    try {
      await _api.postExecutionReject(
        executionId: executionId,
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
        SnackBar(
            content: Text(userFacingMessage(e)),
            backgroundColor: Colors.red.shade700),
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
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
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
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red.shade700)),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _load,
                            child: const Text('Tentar novamente')),
                      ],
                    ),
                  ),
                )
              : _allItems.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Nenhuma confirmação pendente.',
                              style: TextStyle(color: AppTheme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'As solicitações aparecem aqui quando alguém indicar você como adversário. '
                              'Certifique-se de estar com seu usuário selecionado no início da página (Área do aluno).',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Buscar por executor ou técnica',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            _applyFilters();
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (_) => _applyFilters(),
                              ),
                              if (_searchController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Mostrando ${_filteredItems.length} de ${_allItems.length}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          _applyFilters();
                                        },
                                        child: const Text('Limpar'),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            child: _filteredItems.isEmpty
                                ? Center(
                                    child: Text(
                                      _searchController.text.isNotEmpty
                                          ? 'Nenhuma confirmação encontrada.'
                                          : 'Nenhuma confirmação pendente.',
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredItems.length,
                                    itemBuilder: (context, i) {
                                      final e = _filteredItems[i];
                                      final id = e['id'] as String?;
                                      final executorName =
                                          e['executor_name'] as String? ??
                                              'Alguém';
                                      final executorGrad =
                                          e['executor_graduation'] as String?;
                                      final faixa = _faixaLabel(executorGrad);
                                      final nameWithFaixa = faixa.isNotEmpty
                                          ? '$executorName (faixa $faixa)'
                                          : executorName;
                                      final techniqueName =
                                          e['technique_name'] as String? ??
                                              'a técnica';
                                      final narrow = AppTheme.isNarrow(context);
                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                '$nameWithFaixa disse que aplicou $techniqueName em você.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge,
                                              ),
                                              const SizedBox(height: 12),
                                              if (narrow)
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    FilledButton(
                                                      onPressed: id == null
                                                          ? null
                                                          : () => _confirm(id,
                                                              'executed_successfully'),
                                                      child: const Text(
                                                          'Executou com sucesso'),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    TextButton(
                                                      onPressed: id == null
                                                          ? null
                                                          : () => _confirm(id,
                                                              'attempted_correctly'),
                                                      child: const Text(
                                                          'Tentativa correta'),
                                                    ),
                                                    TextButton(
                                                      onPressed: id == null
                                                          ? null
                                                          : () =>
                                                              _rejectDontRemember(
                                                                  id),
                                                      child: Text('Não lembro',
                                                          style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade700)),
                                                    ),
                                                  ],
                                                )
                                              else
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    TextButton(
                                                      onPressed: id == null
                                                          ? null
                                                          : () =>
                                                              _rejectDontRemember(
                                                                  id),
                                                      child: Text('Não lembro',
                                                          style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade700)),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    TextButton(
                                                      onPressed: id == null
                                                          ? null
                                                          : () => _confirm(id,
                                                              'attempted_correctly'),
                                                      child: const Text(
                                                          'Tentativa correta'),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    FilledButton(
                                                      onPressed: id == null
                                                          ? null
                                                          : () => _confirm(id,
                                                              'executed_successfully'),
                                                      child: const Text(
                                                          'Executou com sucesso'),
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
                        ),
                      ],
                    ),
    );
  }
}
