import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

/// Lista de execuções criadas pelo usuário (executor). Mostra status e mensagem quando o adversário não aceitou.
class MyExecutionsScreen extends StatefulWidget {
  final String userId;

  const MyExecutionsScreen({super.key, required this.userId});

  @override
  State<MyExecutionsScreen> createState() => _MyExecutionsScreenState();
}

class _MyExecutionsScreenState extends State<MyExecutionsScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  String? _filterStatus;
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
        final techniqueName =
            (e['technique_name'] as String? ?? '').toLowerCase();
        final opponentName =
            (e['opponent_name'] as String? ?? '').toLowerCase();
        return techniqueName.contains(query) || opponentName.contains(query);
      }).toList();
    }
    if (_filterStatus != null) {
      filtered = filtered.where((e) => e['status'] == _filterStatus).toList();
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
      final list = await _api.getMyExecutions();
      if (mounted) {
        setState(() {
          _allItems = list;
          _loading = false;
        });
      }
      _applyFilters();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(e);
          _loading = false;
        });
      }
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
                      child: Text(
                        'Nenhuma solicitação de confirmação.',
                        style: TextStyle(color: AppTheme.textSecondary),
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
                                  hintText: 'Buscar por técnica ou adversário',
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
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilterChip(
                                    label: const Text('Todos'),
                                    selected: _filterStatus == null,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _filterStatus = null);
                                        _applyFilters();
                                      }
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('Pendente'),
                                    selected:
                                        _filterStatus == 'pending_confirmation',
                                    onSelected: (selected) {
                                      setState(() => _filterStatus = selected
                                          ? 'pending_confirmation'
                                          : null);
                                      _applyFilters();
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('Confirmado'),
                                    selected: _filterStatus == 'confirmed',
                                    onSelected: (selected) {
                                      setState(() => _filterStatus =
                                          selected ? 'confirmed' : null);
                                      _applyFilters();
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('Recusado'),
                                    selected: _filterStatus == 'rejected',
                                    onSelected: (selected) {
                                      setState(() => _filterStatus =
                                          selected ? 'rejected' : null);
                                      _applyFilters();
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('Não aceitou'),
                                    selected: _filterStatus ==
                                        'rejected_dont_remember',
                                    onSelected: (selected) {
                                      setState(() => _filterStatus = selected
                                          ? 'rejected_dont_remember'
                                          : null);
                                      _applyFilters();
                                    },
                                  ),
                                ],
                              ),
                              if (_searchController.text.isNotEmpty ||
                                  _filterStatus != null)
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
                                          setState(() => _filterStatus = null);
                                          _applyFilters();
                                        },
                                        child: const Text('Limpar filtros'),
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
                                      _searchController.text.isNotEmpty ||
                                              _filterStatus != null
                                          ? 'Nenhuma solicitação encontrada.'
                                          : 'Nenhuma solicitação de confirmação.',
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredItems.length,
                                    itemBuilder: (context, i) {
                                      final e = _filteredItems[i];
                                      final status = e['status'] as String?;
                                      final techniqueName =
                                          e['technique_name'] as String? ??
                                              'técnica';
                                      final opponentName =
                                          e['opponent_name'] as String? ??
                                              'Colega';
                                      final opponentGrad =
                                          e['opponent_graduation'] as String?;
                                      final faixa = _faixaLabel(opponentGrad);
                                      final opponentWithFaixa = faixa.isNotEmpty
                                          ? '$opponentName (faixa $faixa)'
                                          : opponentName;
                                      final isRejectedDontRemember =
                                          status == 'rejected_dont_remember';
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
                                                techniqueName,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      color:
                                                          AppTheme.textPrimary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Em $opponentWithFaixa',
                                                style: const TextStyle(
                                                    color:
                                                        AppTheme.textSecondary,
                                                    fontSize: 13),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          isRejectedDontRemember
                                                              ? Colors.orange
                                                                  .shade100
                                                              : status ==
                                                                      'confirmed'
                                                                  ? Colors.green
                                                                      .shade100
                                                                  : status ==
                                                                          'pending_confirmation'
                                                                      ? Colors
                                                                          .blue
                                                                          .shade100
                                                                      : Colors
                                                                          .grey
                                                                          .shade200,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      _statusLabel(status),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            isRejectedDontRemember
                                                                ? Colors.orange
                                                                    .shade900
                                                                : status ==
                                                                        'confirmed'
                                                                    ? Colors
                                                                        .green
                                                                        .shade900
                                                                    : null,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (isRejectedDontRemember) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  '$opponentWithFaixa não aceitou a posição atribuída a você.',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        Colors.orange.shade800,
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
                        ),
                      ],
                    ),
    );
  }
}
