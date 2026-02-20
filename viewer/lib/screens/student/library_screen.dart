import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/screens/student/lesson_view_data.dart';
import 'package:viewer/screens/student/lesson_view_screen.dart';
import 'package:viewer/services/api_service.dart';

/// Lista de lições (GET /lessons). Se [academyId] for passado, a lição visível da academia aparece em destaque.
class LibraryScreen extends StatefulWidget {
  final String userId;
  final String? academyId;

  const LibraryScreen({super.key, required this.userId, this.academyId});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  List<Lesson> _featuredLessons = [];
  List<Lesson> _allLessons = [];
  List<Lesson> _filteredFeaturedLessons = [];
  List<Lesson> _filteredAllLessons = [];
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
    var filteredFeatured = _featuredLessons;
    var filteredAll = _allLessons;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filteredFeatured = filteredFeatured.where((l) => l.title.toLowerCase().contains(query)).toList();
      filteredAll = filteredAll.where((l) => l.title.toLowerCase().contains(query)).toList();
    }
    if (_filterTechniqueId != null) {
      filteredFeatured = filteredFeatured.where((l) => l.techniqueId == _filterTechniqueId).toList();
      filteredAll = filteredAll.where((l) => l.techniqueId == _filterTechniqueId).toList();
    }
    setState(() {
      _filteredFeaturedLessons = filteredFeatured;
      _filteredAllLessons = filteredAll;
    });
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
      final results = await Future.wait([
        widget.academyId != null ? _api.getLessons(academyId: widget.academyId) : Future.value(<Lesson>[]),
        _api.getLessons(),
        widget.academyId != null
            ? _api.getTechniques(academyId: widget.academyId!)
            : Future.value(<Technique>[]),
      ]);
      if (mounted) setState(() {
        _featuredLessons = results[0] as List<Lesson>;
        _allLessons = results[1] as List<Lesson>;
        _techniques = results[2] as List<Technique>;
        _loading = false;
        _loadingTechniques = false;
      });
      _applyFilters();
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _loadingTechniques = false;
        _error = userFacingMessage(e);
      });
    }
  }


  Widget? _lessonSubtitle(Lesson lesson) {
    final parts = <String>[];
    if (lesson.techniqueName != null && lesson.techniqueName!.isNotEmpty) {
      parts.add(lesson.positionName != null && lesson.positionName!.isNotEmpty
          ? '${lesson.techniqueName!} ${lesson.positionName}'
          : lesson.techniqueName!);
    }
    if (lesson.content != null && lesson.content!.isNotEmpty) {
      parts.add(lesson.content!.length > 60 ? '${lesson.content!.substring(0, 60)}...' : lesson.content!);
    }
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary));
  }

  void _openLesson(Lesson lesson) {
    final data = LessonViewData(
      lessonId: lesson.id,
      missionId: null,
      title: lesson.title,
      description: lesson.content ?? '',
      videoUrl: (lesson.techniqueVideoUrl != null && lesson.techniqueVideoUrl!.trim().isNotEmpty)
          ? lesson.techniqueVideoUrl!
          : (lesson.videoUrl ?? ''),
      userId: widget.userId,
      academyId: widget.academyId,
      techniqueName: lesson.techniqueName,
      positionName: lesson.positionName,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonViewScreen(data: data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca de lições')),
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
              : _allLessons.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma lição cadastrada.',
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
                                value: _filterTechniqueId,
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
                                          'Mostrando ${_filteredFeaturedLessons.length + _filteredAllLessons.length} de ${_featuredLessons.length + _allLessons.length}',
                                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                          child: _filteredFeaturedLessons.isEmpty && _filteredAllLessons.isEmpty
                              ? Center(
                                  child: Text(
                                    _searchController.text.isNotEmpty || _filterTechniqueId != null
                                        ? 'Nenhuma lição encontrada.'
                                        : 'Nenhuma lição cadastrada.',
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                )
                              : ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    if (_filteredFeaturedLessons.isNotEmpty) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          'Lição em destaque',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      ..._filteredFeaturedLessons.map((lesson) => Card(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            child: ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                                                child: const Icon(Icons.star, color: AppTheme.primary),
                                              ),
                                              title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              subtitle: _lessonSubtitle(lesson),
                                              trailing: const Icon(Icons.chevron_right),
                                              onTap: () => _openLesson(lesson),
                                            ),
                                          )),
                                      const SizedBox(height: 16),
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          'Todas as lições',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                color: AppTheme.textSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                    ..._filteredAllLessons.map((lesson) => Card(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                                              child: const Icon(Icons.menu_book, color: AppTheme.primary),
                                            ),
                                            title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                            subtitle: _lessonSubtitle(lesson),
                                            trailing: const Icon(Icons.chevron_right),
                                            onTap: () => _openLesson(lesson),
                                          ),
                                        )),
                                  ],
                                ),
                        ),
                      ],
                    ),
    );
  }
}
