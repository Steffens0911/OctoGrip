import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/screens/admin/lesson_form_screen.dart';
import 'package:viewer/utils/error_message.dart';

class LessonListScreen extends StatefulWidget {
  const LessonListScreen({super.key});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  List<Lesson> _allItems = [];
  List<Lesson> _filteredItems = [];
  List<Technique> _techniques = [];
  String? _filterTechniqueId;
  bool _loading = true;
  bool _loadingTechniques = true;
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
      filtered = filtered.where((l) => l.title.toLowerCase().contains(query)).toList();
    }
    if (_filterTechniqueId != null) {
      filtered = filtered.where((l) => l.techniqueId == _filterTechniqueId).toList();
    }
    setState(() => _filteredItems = filtered);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getLessons(),
        _api.getTechniques(),
      ]);
      if (mounted) {
        setState(() {
        _allItems = results[0] as List<Lesson>;
        _techniques = results[1] as List<Technique>;
        _loading = false;
        _loadingTechniques = false;
      });
      }
      _applyFilters();
    } catch (e) {
      if (mounted) setState(() { _error = userFacingMessage(e); _loading = false; _loadingTechniques = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _lessonTechniqueDisplay(Lesson l) {
    if (l.techniqueName != null && l.techniqueName!.isNotEmpty) {
      return l.positionName != null && l.positionName!.isNotEmpty
          ? '${l.techniqueName!} ${l.positionName}'
          : l.techniqueName!;
    }
    return l.techniqueId;
  }

  Future<void> _openForm([Lesson? l]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => LessonFormScreen(lesson: l)));
    if (mounted) _load();
  }

  Future<void> _delete(Lesson l) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Excluir lição'),
      content: Text('Excluir "${l.title}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
      ],
    ));
    if (ok != true) return;
    try {
      await _api.deleteLesson(l.id);
      if (mounted) _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lição excluída')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lições'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!), const SizedBox(height: 16), ElevatedButton(onPressed: _load, child: const Text('Tentar novamente'))]))
          : _allItems.isEmpty ? const Center(child: Text('Nenhuma lição. Toque em + para criar.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por título da lição',
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
                        initialValue: _filterTechniqueId,
                        decoration: const InputDecoration(
                          labelText: 'Técnica',
                          hintText: 'Todas',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todas')),
                          ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                        ],
                        onChanged: (v) {
                          setState(() => _filterTechniqueId = v);
                          _applyFilters();
                        },
                      ),
                      if (_searchController.text.isNotEmpty || _filterTechniqueId != null)
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
                                  setState(() => _filterTechniqueId = null);
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
                              _searchController.text.isNotEmpty || _filterTechniqueId != null
                                  ? 'Nenhuma lição encontrada.'
                                  : 'Nenhuma lição. Toque em + para criar.',
                              style: const const const TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, i) {
                              final l = _filteredItems[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(l.title),
                      subtitle: Text('${_lessonTechniqueDisplay(l)} · ordem ${l.orderIndex}'),
                      trailing: AuthService().canEditResources() ? Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, color: AppTheme.primary), onPressed: () => _openForm(l)),
                        IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), onPressed: () => _delete(l)),
                      ]) : null,
                      onTap: () => _openForm(l),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
