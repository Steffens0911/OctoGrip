import 'dart:async';

import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/user.dart' as models;
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/screens/admin/user_form_screen.dart';
import 'package:viewer/features/trophy_shelf/presentation/trophy_shelf_page.dart';
import 'package:viewer/utils/error_message.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<models.UserModel> _allItems = [];
  List<models.UserModel> _filteredItems = [];
  List<Academy> _academies = [];
  String? _filterAcademyId;
  String? _filterGraduation;
  bool _loading = true;
  bool _loadingAcademies = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 50;
  String? _error;

  static const List<MapEntry<String, String>> _graduations = [
    MapEntry('white', 'Branca'),
    MapEntry('blue', 'Azul'),
    MapEntry('purple', 'Roxa'),
    MapEntry('brown', 'Marrom'),
    MapEntry('black', 'Preta'),
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    var filtered = _allItems;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((u) {
        final name = (u.name ?? '').toLowerCase();
        final email = u.email.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }
    if (_filterAcademyId != null) {
      filtered = filtered.where((u) => u.academyId == _filterAcademyId).toList();
    }
    if (_filterGraduation != null) {
      filtered = filtered.where((u) => u.graduation == _filterGraduation).toList();
    }
    setState(() => _filteredItems = filtered);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _currentPage = 0; _hasMore = true; });
    final isAdmin = AuthService().isAdmin();
    try {
      final results = await Future.wait([
        isAdmin
            ? _api.getUsers(offset: 0, limit: _pageSize)
            : _api.getUsers(academyId: AuthService().currentUser?.academyId, offset: 0, limit: _pageSize),
        _api.getAcademies(),
      ]);
      final list = results[0] as List<models.UserModel>;
      if (mounted) setState(() {
        _allItems = list;
        _academies = results[1] as List<Academy>;
        _loading = false;
        _loadingAcademies = false;
        _hasMore = list.length >= _pageSize;
      });
      _applyFilters();
    } catch (e) {
      if (mounted) setState(() { _error = userFacingMessage(e); _loading = false; _loadingAcademies = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    final isAdmin = AuthService().isAdmin();
    try {
      final nextOffset = (_currentPage + 1) * _pageSize;
      final list = isAdmin
          ? await _api.getUsers(offset: nextOffset, limit: _pageSize)
          : await _api.getUsers(academyId: AuthService().currentUser?.academyId, offset: nextOffset, limit: _pageSize);
      if (mounted) setState(() {
        _allItems = [..._allItems, ...list];
        _currentPage++;
        _hasMore = list.length >= _pageSize;
        _isLoadingMore = false;
      });
      _applyFilters();
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openForm([models.UserModel? user]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => UserFormScreen(user: user)));
    if (mounted) _load();
  }

  Future<void> _delete(models.UserModel u) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Excluir usuário'),
      content: Text('Excluir "${u.email}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
      ],
    ));
    if (ok != true) return;
    try {
      await _api.deleteUser(u.id);
      if (mounted) _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário excluído')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = _searchController.text.isNotEmpty || _filterAcademyId != null || _filterGraduation != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!), const SizedBox(height: 16), ElevatedButton(onPressed: _load, child: const Text('Tentar novamente'))]))
          : _allItems.isEmpty ? const Center(child: Text('Nenhum usuário. Toque em + para criar.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por nome ou email',
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
                        onChanged: (_) {
                          _debounceTimer?.cancel();
                          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (AuthService().isAdmin())
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _filterAcademyId,
                                decoration: const InputDecoration(
                                  labelText: 'Academia',
                                  hintText: 'Todas',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  isDense: true,
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Todas')),
                                  ..._academies.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                                ],
                                onChanged: (v) {
                                  setState(() => _filterAcademyId = v);
                                  _applyFilters();
                                },
                              ),
                            ),
                          if (AuthService().isAdmin()) const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _filterGraduation,
                              decoration: const InputDecoration(
                                labelText: 'Graduação',
                                hintText: 'Todas',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Todas')),
                                ..._graduations.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                              ],
                              onChanged: (v) {
                                setState(() => _filterGraduation = v);
                                _applyFilters();
                              },
                            ),
                          ),
                        ],
                      ),
                      if (hasFilters)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Mostrando ${_filteredItems.length} de ${_allItems.length}',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _filterAcademyId = null;
                                    _filterGraduation = null;
                                  });
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
                              hasFilters ? 'Nenhum usuário encontrado.' : 'Nenhum usuário. Toque em + para criar.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: AppTheme.screenPadding(context)),
                            itemCount: _filteredItems.length + (_hasMore && !_isLoadingMore ? 1 : 0) + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == _filteredItems.length) {
                                // Botão "Carregar mais" ou indicador de loading
                                if (_isLoadingMore) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                if (_hasMore) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: FilledButton(
                                      onPressed: _loadMore,
                                      child: const Text('Carregar mais'),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }
                              final u = _filteredItems[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(u.email),
                                  subtitle: Text(u.name ?? '—'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.emoji_events_outlined),
                                        tooltip: 'Ver galeria de troféus',
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TrophyShelfPage(
                                              userId: u.id,
                                              userName: u.name ?? u.email,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (AuthService().canEditResources()) ...[
                                        IconButton(icon: const Icon(Icons.edit, color: AppTheme.primary), onPressed: () => _openForm(u)),
                                        IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), onPressed: () => _delete(u)),
                                      ],
                                    ],
                                  ),
                                  onTap: () => _openForm(u),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: AuthService().canEditResources() ? FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)) : null,
    );
  }
}
