import 'dart:async';

import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/screens/admin/lesson_form_screen.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class LessonListScreen extends StatefulWidget {
  const LessonListScreen({super.key});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  static const int _pageSize = 50;
  List<Lesson> _allItems = [];
  List<Lesson> _filteredItems = [];
  List<Technique> _techniques = [];
  String? _filterTechniqueId;
  String _searchQuery = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _error;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _applyTechniqueFilter() {
    if (_filterTechniqueId == null) {
      setState(() => _filteredItems = _allItems);
    } else {
      setState(() => _filteredItems = _allItems.where((l) => l.techniqueId == _filterTechniqueId).toList());
    }
  }

  Future<void> _load({bool reset = true}) async {
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _offset = 0;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final academyId = AuthService().currentUser?.academyId ?? '';
      if (reset) {
        final results = await Future.wait([
          _api.getLessons(
            academyId: academyId.isNotEmpty ? academyId : null,
            offset: 0,
            limit: _pageSize,
            search: _searchQuery.isNotEmpty ? _searchQuery : null,
          ),
          _api.getTechniques(academyId: academyId),
        ]);
        if (mounted) {
          final list = results[0] as List<Lesson>;
          setState(() {
            _allItems = list;
            _techniques = results[1] as List<Technique>;
            _offset = list.length;
            _hasMore = list.length == _pageSize;
            _loading = false;
          });
          _applyTechniqueFilter();
        }
      } else {
        final list = await _api.getLessons(
          academyId: academyId.isNotEmpty ? academyId : null,
          offset: _offset,
          limit: _pageSize,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
        );
        if (mounted) {
          setState(() {
            _allItems = [..._allItems, ...list];
            _offset += list.length;
            _hasMore = list.length == _pageSize;
            _loadingMore = false;
          });
          _applyTechniqueFilter();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(e);
          if (reset) {
            _loading = false;
          } else {
            _loadingMore = false;
          }
        });
      }
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
      if (mounted) {
        AppFeedback.show(context, message: 'Lição excluída', type: AppFeedbackType.success);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Lições'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!), const SizedBox(height: 16), ElevatedButton(onPressed: _load, child: const Text('Tentar novamente'))]))
              : _allItems.isEmpty && _searchQuery.isEmpty
                  ? const Center(child: Text('Nenhuma lição. Toque em + para criar.'))
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
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                            _load(reset: true);
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (v) {
                                  _debounceTimer?.cancel();
                                  _debounceTimer = Timer(const Duration(milliseconds: 400), () {
                                    setState(() => _searchQuery = v.trim());
                                    _load(reset: true);
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _filterTechniqueId,
                                decoration: const InputDecoration(labelText: 'Técnica', hintText: 'Todas', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16), isDense: true),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Todas')),
                                  ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                                ],
                                onChanged: (v) {
                                  setState(() => _filterTechniqueId = v);
                                  _applyTechniqueFilter();
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () => _load(reset: true),
                            child: _filteredItems.isEmpty
                                ? const Center(child: Text('Nenhuma lição encontrada.', style: TextStyle(color: AppTheme.textSecondary)))
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredItems.length + (_hasMore ? 1 : 0),
                                    itemBuilder: (context, i) {
                                      if (i >= _filteredItems.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Center(
                                            child: _loadingMore
                                                ? const CircularProgressIndicator()
                                                : OutlinedButton.icon(
                                                    onPressed: () => _load(reset: false),
                                                    icon: const Icon(Icons.expand_more),
                                                    label: const Text('Carregar mais'),
                                                  ),
                                          ),
                                        );
                                      }
                                      final l = _filteredItems[i];
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          title: Text(l.title),
                                          subtitle: Text('${_lessonTechniqueDisplay(l)} · ordem ${l.orderIndex}'),
                                          trailing: AuthService().canEditResources()
                                              ? Row(mainAxisSize: MainAxisSize.min, children: [
                                                  IconButton(icon: const Icon(Icons.edit, color: AppTheme.primary), onPressed: () => _openForm(l)),
                                                  IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), onPressed: () => _delete(l)),
                                                ])
                                              : null,
                                          onTap: () => _openForm(l),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: AuthService().canEditResources()
          ? FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add))
          : null,
    );
  }
}
