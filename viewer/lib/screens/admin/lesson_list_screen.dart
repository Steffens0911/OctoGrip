import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/models/position.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/screens/admin/lesson_form_screen.dart';

class LessonListScreen extends StatefulWidget {
  const LessonListScreen({super.key});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final _api = ApiService();
  List<Lesson> _list = [];
  List<Technique> _techniques = [];
  List<Position> _positions = [];
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([_api.getLessons(), _api.getTechniques(), _api.getPositions()]);
      setState(() {
        _list = results[0] as List<Lesson>;
        _techniques = results[1] as List<Technique>;
        _positions = results[2] as List<Position>;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() {
        _error = 'Erro de conexão. A API está rodando em ${_api.baseUrl}?';
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _positionName(String id) => _positions.where((p) => p.id == id).map((p) => p.name).firstOrNull ?? id;

  String _techniqueWithPosition(String techniqueId) {
    final t = _techniques.where((x) => x.id == techniqueId).firstOrNull;
    if (t == null) return techniqueId;
    final from = _positionName(t.fromPositionId);
    final to = _positionName(t.toPositionId);
    return '${t.name} da posição $from → para posição $to';
  }

  String _lessonTechniqueDisplay(Lesson l) {
    if (l.techniqueName != null && l.techniqueName!.isNotEmpty) {
      return l.positionName != null && l.positionName!.isNotEmpty
          ? '${l.techniqueName!} ${l.positionName}'
          : l.techniqueName!;
    }
    return _techniqueWithPosition(l.techniqueId);
  }

  Future<void> _openForm([Lesson? l]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => LessonFormScreen(lesson: l)));
    _load();
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
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lição excluída')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lições'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!), const SizedBox(height: 16), ElevatedButton(onPressed: _load, child: const Text('Tentar novamente'))]))
          : _list.isEmpty ? const Center(child: Text('Nenhuma lição. Toque em + para criar.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _list.length,
                itemBuilder: (context, i) {
                  final l = _list[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(l.title),
                      subtitle: Text('${_lessonTechniqueDisplay(l)} · ordem ${l.orderIndex}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, color: AppTheme.primary), onPressed: () => _openForm(l)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(l)),
                      ]),
                      onTap: () => _openForm(l),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
    );
  }
}
