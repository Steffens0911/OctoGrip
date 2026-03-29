import 'dart:async';

import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/screens/student/lesson_view_data.dart';
import 'package:viewer/screens/student/lesson_view_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/widgets/app_list_scaffold.dart';
import 'package:viewer/widgets/app_screen_state.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

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
  Timer? _debounceTimer;
  List<Lesson> _featuredLessons = [];
  List<Lesson> _allLessons = [];
  List<Lesson> _filteredFeaturedLessons = [];
  List<Lesson> _filteredAllLessons = [];
  List<Technique> _techniques = [];
  String? _filterTechniqueId;
  bool _loading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 50;
  String? _error;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    var filteredFeatured = _featuredLessons;
    var filteredAll = _allLessons;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filteredFeatured = filteredFeatured
          .where((l) => l.title.toLowerCase().contains(query))
          .toList();
      filteredAll = filteredAll
          .where((l) => l.title.toLowerCase().contains(query))
          .toList();
    }
    if (_filterTechniqueId != null) {
      filteredFeatured = filteredFeatured
          .where((l) => l.techniqueId == _filterTechniqueId)
          .toList();
      filteredAll = filteredAll
          .where((l) => l.techniqueId == _filterTechniqueId)
          .toList();
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

  Future<void> _load({bool loadMore = false}) async {
    if (loadMore && (_isLoadingMore || !_hasMore)) return;

    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _currentPage = 0;
        _allLessons = [];
        _hasMore = true;
      });
    }

    try {
      final page = loadMore ? _currentPage + 1 : 0;
      final results = await Future.wait([
        widget.academyId != null
            ? _api.getLessons(
                academyId: widget.academyId, offset: 0, limit: 100)
            : Future.value(<Lesson>[]),
        _api.getLessons(offset: page * _pageSize, limit: _pageSize),
        page == 0 && widget.academyId != null
            ? _api.getTechniques(academyId: widget.academyId!)
            : Future.value(_techniques),
      ]);

      final newLessons = results[1] as List<Lesson>;
      if (mounted) {
        setState(() {
          if (loadMore) {
            _allLessons.addAll(newLessons);
            _currentPage = page;
            _hasMore = newLessons.length == _pageSize;
          } else {
            _featuredLessons = results[0] as List<Lesson>;
            _allLessons = newLessons;
            _techniques = results[2] as List<Technique>;
            _currentPage = 0;
            _hasMore = newLessons.length == _pageSize;
          }
          _loading = false;
          _isLoadingMore = false;
        });
      }
      _applyFilters();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isLoadingMore = false;
          _error = userFacingMessage(e);
        });
      }
    }
  }

  Future<void> _loadMore() async {
    await _load(loadMore: true);
  }

  Widget? _lessonSubtitle(Lesson lesson) {
    final parts = <String>[];
    if (lesson.techniqueName != null && lesson.techniqueName!.isNotEmpty) {
      parts.add(lesson.positionName != null && lesson.positionName!.isNotEmpty
          ? '${lesson.techniqueName!} ${lesson.positionName}'
          : lesson.techniqueName!);
    }
    if (lesson.content != null && lesson.content!.isNotEmpty) {
      parts.add(lesson.content!.length > 60
          ? '${lesson.content!.substring(0, 60)}...'
          : lesson.content!);
    }
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '),
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary));
  }

  int _getTotalItemCount() {
    int count = 0;
    if (_filteredFeaturedLessons.isNotEmpty) {
      count += 1; // Header "Lição em destaque"
      count += _filteredFeaturedLessons.length;
      count += 1; // SizedBox
      count += 1; // Header "Todas as lições"
    }
    count += _filteredAllLessons.length;
    // Adicionar item para "Carregar mais" se não houver filtros ativos e houver mais itens
    final hasActiveFilters =
        _searchController.text.isNotEmpty || _filterTechniqueId != null;
    if (!hasActiveFilters && _hasMore && !_isLoadingMore) {
      count += 1; // Botão "Carregar mais"
    }
    if (_isLoadingMore) {
      count += 1; // Indicador de loading
    }
    return count;
  }

  Widget _buildListItem(BuildContext context, int index) {
    int currentIndex = 0;

    if (_filteredFeaturedLessons.isNotEmpty) {
      if (index == currentIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Lição em destaque',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        );
      }
      currentIndex++;

      if (index < currentIndex + _filteredFeaturedLessons.length) {
        final lesson = _filteredFeaturedLessons[index - currentIndex];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
              child: const Icon(Icons.star, color: AppTheme.primary),
            ),
            title: Text(lesson.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: _lessonSubtitle(lesson),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openLesson(lesson),
          ),
        );
      }
      currentIndex += _filteredFeaturedLessons.length;

      if (index == currentIndex) {
        return const SizedBox(height: 16);
      }
      currentIndex++;

      if (index == currentIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Todas as lições',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        );
      }
      currentIndex++;
    }

    // Verificar se é o botão "Carregar mais" ou indicador de loading
    final hasActiveFilters =
        _searchController.text.isNotEmpty || _filterTechniqueId != null;
    if (!hasActiveFilters) {
      if (index == currentIndex + _filteredAllLessons.length) {
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
      }
    }

    final lesson = _filteredAllLessons[index - currentIndex];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
          child: const Icon(Icons.menu_book, color: AppTheme.primary),
        ),
        title: Text(lesson.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: _lessonSubtitle(lesson),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openLesson(lesson),
      ),
    );
  }

  void _openLesson(Lesson lesson) {
    final data = LessonViewData(
      lessonId: lesson.id,
      missionId: null,
      title: lesson.title,
      description: lesson.content ?? '',
      videoUrl: (lesson.techniqueVideoUrl != null &&
              lesson.techniqueVideoUrl!.trim().isNotEmpty)
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
      appBar: const AppStandardAppBar(title: 'Biblioteca de lições'),
      body: _loading
          ? const AppScreenState.loading()
          : _error != null
              ? AppScreenState.error(message: _error!, onRetry: _load)
              : _allLessons.isEmpty
                  ? const AppScreenState.empty(
                      message: 'Nenhuma lição cadastrada.',
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
                                onChanged: (_) {
                                  _debounceTimer?.cancel();
                                  _debounceTimer = Timer(
                                      const Duration(milliseconds: 300), () {
                                    _applyFilters();
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _filterTechniqueId,
                                decoration: const InputDecoration(
                                  labelText: 'Técnica',
                                  hintText: 'Todas',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 16),
                                  isDense: true,
                                ),
                                items: [
                                  const DropdownMenuItem(
                                      value: null, child: Text('Todas')),
                                  ..._techniques.map((t) => DropdownMenuItem(
                                      value: t.id, child: Text(t.name))),
                                ],
                                onChanged: (v) {
                                  setState(() => _filterTechniqueId = v);
                                  _applyFilters();
                                },
                              ),
                              if (_searchController.text.isNotEmpty ||
                                  _filterTechniqueId != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Mostrando ${_filteredFeaturedLessons.length + _filteredAllLessons.length} de ${_featuredLessons.length + _allLessons.length}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(
                                              () => _filterTechniqueId = null);
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
                          child: _filteredFeaturedLessons.isEmpty &&
                                  _filteredAllLessons.isEmpty
                              ? const AppScreenState.empty(
                                  message: 'Nenhuma lição encontrada.')
                              : AppListScaffold(
                                  onRefresh: () => _load(),
                                  children: List.generate(
                                    _getTotalItemCount(),
                                    (index) => _buildListItem(context, index),
                                  ),
                                ),
                        ),
                      ],
                    ),
    );
  }
}
