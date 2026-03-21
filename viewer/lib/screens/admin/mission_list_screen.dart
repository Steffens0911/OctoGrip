import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/mission.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/screens/admin/mission_form_screen.dart';
import 'package:viewer/utils/error_message.dart';

class MissionListScreen extends StatefulWidget {
  const MissionListScreen({super.key});

  @override
  State<MissionListScreen> createState() => _MissionListScreenState();
}

class _MissionListScreenState extends State<MissionListScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  List<Mission> _allItems = [];
  List<Mission> _filteredItems = [];
  String? _filterLevel;
  bool _loading = true;
  String? _error;

  static const List<MapEntry<String, String>> _levels = [
    MapEntry('beginner', 'Iniciante'),
    MapEntry('intermediate', 'Intermediário'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    var filtered = _allItems;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((m) {
        final theme = (m.theme ?? '').toLowerCase();
        final techniqueName = (m.techniqueName ?? '').toLowerCase();
        return theme.contains(query) || techniqueName.contains(query);
      }).toList();
    }
    if (_filterLevel != null) {
      filtered = filtered.where((m) => m.level == _filterLevel).toList();
    }
    setState(() => _filteredItems = filtered);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getMissions();
      if (mounted) {
        setState(() {
        _allItems = list;
        _loading = false;
      });
      }
      _applyFilters();
    } catch (e) {
      if (mounted) setState(() { _error = userFacingMessage(e); _loading = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _missionTitle(Mission m) {
    if (m.theme != null && m.theme!.isNotEmpty) {
      return m.theme!;
    }
    return m.techniqueName ?? m.techniqueId;
  }

  Future<void> _openForm([Mission? m]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => MissionFormScreen(mission: m)));
    if (mounted) _load();
  }

  Future<void> _delete(Mission m) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Excluir missão'),
      content: Text('Excluir missão ${m.startDate}–${m.endDate}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
      ],
    ));
    if (ok != true) return;
    try {
      await _api.deleteMission(m.id);
      if (mounted) _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missão excluída')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Missões'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!), const SizedBox(height: 16), ElevatedButton(onPressed: _load, child: const Text('Tentar novamente'))]))
          : _allItems.isEmpty ? const Center(child: Text('Nenhuma missão. Toque em + para criar.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por tema ou técnica',
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
                      DropdownButtonFormField<String>(
                        initialValue: _filterLevel,
                        decoration: const InputDecoration(
                          labelText: 'Nível',
                          hintText: 'Todos',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todos')),
                          ..._levels.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                        ],
                        onChanged: (v) {
                          setState(() => _filterLevel = v);
                          _applyFilters();
                        },
                      ),
                      if (_searchController.text.isNotEmpty || _filterLevel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Mostrando ${_filteredItems.length} de ${_allItems.length}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _filterLevel = null);
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
                  floatingActionButton: AuthService().canEditResources() ? FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)) : null,
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _filteredItems.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isNotEmpty || _filterLevel != null
                                  ? 'Nenhuma missão encontrada.'
                                  : 'Nenhuma missão. Toque em + para criar.',
                              style: const const const TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, i) {
                              final m = _filteredItems[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(_missionTitle(m)),
                      subtitle: Text('${m.startDate} – ${m.endDate} · ${m.level}${m.theme != null && m.theme!.isNotEmpty ? " · ${m.theme}" : ""}'),
                      trailing: AuthService().canEditResources() ? Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, color: AppTheme.primary), onPressed: () => _openForm(m)),
                        IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), onPressed: () => _delete(m)),
                      ]) : null,
                      onTap: () => _openForm(m),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
