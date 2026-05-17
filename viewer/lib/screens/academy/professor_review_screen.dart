import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Tela para professor/gerente revisar execuções escaladas após 4 dias sem confirmação do adversário.
class ProfessorReviewScreen extends StatefulWidget {
  const ProfessorReviewScreen({super.key});

  @override
  State<ProfessorReviewScreen> createState() => _ProfessorReviewScreenState();
}

class _ProfessorReviewScreenState extends State<ProfessorReviewScreen> {
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
      final list = await _api.getProfessorReviewExecutions();
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

  void _applyFilters() {
    var filtered = _allItems;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((e) {
        final executorName = (e['executor_name'] as String? ?? '').toLowerCase();
        final techniqueName = (e['technique_name'] as String? ?? '').toLowerCase();
        final opponentName = (e['opponent_name'] as String? ?? '').toLowerCase();
        return executorName.contains(query) ||
            techniqueName.contains(query) ||
            opponentName.contains(query);
      }).toList();
    }
    setState(() => _filteredItems = filtered);
  }

  Future<void> _review(String executionId, String outcome) async {
    try {
      await _api.postProfessorReviewExecution(
        executionId: executionId,
        outcome: outcome,
      );
      if (!mounted) return;
      final msg = outcome == 'rejected'
          ? 'Indicação reprovada.'
          : 'Indicação aprovada! Pontos contabilizados.';
      AppFeedback.show(
        context,
        message: msg,
        type: outcome == 'rejected' ? AppFeedbackType.info : AppFeedbackType.success,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
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

  String _nameWithFaixa(String? name, String? grad) {
    final faixa = _faixaLabel(grad);
    if (faixa.isEmpty) return name ?? 'Aluno';
    return '${name ?? 'Aluno'} (faixa $faixa)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(
        title: 'Revisão de indicações',
        subtitle: 'Indicações não confirmadas pelo adversário em 4+ dias',
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
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : _allItems.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhuma indicação aguardando revisão.\n\nQuando um aluno indicar uma posição e o adversário não confirmar em 4 dias, a indicação aparece aqui para você revisar.',
                          style: TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
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
                                  hintText: 'Buscar por aluno, adversário ou técnica',
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
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondaryOf(context),
                                          ),
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
                                      'Nenhuma indicação encontrada.',
                                      style: TextStyle(
                                        color: AppTheme.textSecondaryOf(context),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    itemCount: _filteredItems.length,
                                    itemBuilder: (context, i) {
                                      final e = _filteredItems[i];
                                      final id = e['id'] as String?;
                                      final executorName = _nameWithFaixa(
                                        e['executor_name'] as String?,
                                        e['executor_graduation'] as String?,
                                      );
                                      final opponentName = _nameWithFaixa(
                                        e['opponent_name'] as String?,
                                        e['opponent_graduation'] as String?,
                                      );
                                      final techniqueName =
                                          e['technique_name'] as String? ?? 'a técnica';
                                      final narrow = AppTheme.isNarrow(context);

                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                '$executorName disse que aplicou $techniqueName em $opponentName.',
                                                style: Theme.of(context).textTheme.bodyLarge,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'O adversário não confirmou em 4 dias.',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textSecondaryOf(context),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              if (narrow)
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    FilledButton(
                                                      onPressed: id == null
                                                          ? null
                                                          : () => _review(id, 'executed_successfully'),
                                                      child: const Text('Executou com sucesso'),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    TextButton(
                                                      onPressed: id == null
                                                          ? null
                                                          : () => _review(id, 'attempted_correctly'),
                                                      child: const Text('Tentativa correta'),
                                                    ),
                                                    TextButton(
                                                      onPressed: id == null
                                                          ? null
                                                          : () => _review(id, 'rejected'),
                                                      child: Text(
                                                        'Reprovar',
                                                        style: TextStyle(
                                                          color: AppTheme.textSecondaryOf(context),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              else
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    TextButton(
                                                      onPressed: id == null
                                                          ? null
                                                          : () => _review(id, 'rejected'),
                                                      child: Text(
                                                        'Reprovar',
                                                        style: TextStyle(
                                                          color: AppTheme.textSecondaryOf(context),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    TextButton(
                                                      onPressed: id == null
                                                          ? null
                                                          : () => _review(id, 'attempted_correctly'),
                                                      child: const Text('Tentativa correta'),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    FilledButton(
                                                      onPressed: id == null
                                                          ? null
                                                          : () => _review(id, 'executed_successfully'),
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
                        ),
                      ],
                    ),
    );
  }
}
