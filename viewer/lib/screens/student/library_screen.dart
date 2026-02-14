import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/screens/student/lesson_view_data.dart';
import 'package:viewer/screens/student/lesson_view_screen.dart';
import 'package:viewer/services/api_service.dart';

/// Lista de lições (GET /lessons). Toque abre a lição e permite concluir.
class LibraryScreen extends StatefulWidget {
  final String userId;

  const LibraryScreen({super.key, required this.userId});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _api = ApiService();
  List<Lesson> _lessons = [];
  bool _loading = true;
  String? _error;

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
      final list = await _api.getLessons();
      if (mounted) setState(() {
        _lessons = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
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
              : _lessons.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma lição cadastrada.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _lessons.length,
                      itemBuilder: (context, i) {
                        final lesson = _lessons[i];
                        return Card(
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
                        );
                      },
                    ),
    );
  }
}
