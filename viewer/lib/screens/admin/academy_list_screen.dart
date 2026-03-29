import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/screens/admin/academy_detail_screen.dart';
import 'package:viewer/screens/admin/academy_form_screen.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_list_scaffold.dart';
import 'package:viewer/widgets/app_screen_state.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class AcademyListScreen extends StatefulWidget {
  const AcademyListScreen({super.key});

  @override
  State<AcademyListScreen> createState() => _AcademyListScreenState();
}

class _AcademyListScreenState extends State<AcademyListScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  List<Academy> _allItems = [];
  List<Academy> _filteredItems = [];
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
      filtered = filtered.where((a) => a.name.toLowerCase().contains(query)).toList();
    }
    setState(() => _filteredItems = filtered);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getAcademies();
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openForm([Academy? academy]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AcademyFormScreen(academy: academy),
      ),
    );
    if (mounted) _load();
  }

  void _openDetail(Academy a) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AcademyDetailScreen(
          academy: a,
          onUpdated: _load,
          onDeleted: () {
            if (mounted) Navigator.pop(context);
            _load();
          },
        ),
      ),
    ).then((_) => _load());
  }

  Future<void> _delete(Academy a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir academia'),
        content: Text('Excluir "${a.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteAcademy(a.id);
      if (mounted) _load();
      if (mounted) {
        AppFeedback.show(
          context,
          message: 'Academia excluída',
          type: AppFeedbackType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.show(
          context,
          message: userFacingMessage(e),
          type: AppFeedbackType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppStandardAppBar(
        title: 'Academias',
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Buscar academia'),
                  content: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Digite o nome da academia',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => _applyFilters(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Limpar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const AppScreenState.loading()
          : _error != null
              ? AppScreenState.error(message: _error!, onRetry: _load)
              : _allItems.isEmpty
                  ? const AppScreenState.empty(
                      message: 'Nenhuma academia. Toque em + para criar.',
                    )
                  : AppScreenState.content(
                      child: AppListScaffold(
                        onRefresh: _load,
                        topFilters: (_searchController.text.isNotEmpty ||
                                _filteredItems.length != _allItems.length)
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Mostrando ${_filteredItems.length} de ${_allItems.length}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        _applyFilters();
                                      },
                                      child: const Text('Limpar filtros'),
                                    ),
                                  ],
                                ),
                              )
                            : null,
                        children: _filteredItems.isEmpty
                            ? [
                                const SizedBox(height: 120),
                                const AppScreenState.empty(
                                  message: 'Nenhuma academia encontrada.',
                                ),
                              ]
                            : _filteredItems.map((a) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          AppTheme.primary.withValues(alpha: 0.2),
                                      child: const Icon(Icons.school,
                                          color: AppTheme.primary),
                                    ),
                                    title: Text(a.name),
                                    subtitle: Text(
                                      a.weeklyTheme ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: AuthService().canEditResources()
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit,
                                                    color: AppTheme.primary),
                                                onPressed: () => _openForm(a),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.delete_outline,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .error),
                                                onPressed: () => _delete(a),
                                              ),
                                            ],
                                          )
                                        : null,
                                    onTap: () => _openDetail(a),
                                  ),
                                );
                              }).toList(),
                      ),
                    ),
      floatingActionButton: AuthService().canEditResources() ? FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ) : null,
    );
  }
}
