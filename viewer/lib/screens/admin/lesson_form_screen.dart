import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/services/api_service.dart';

class LessonFormScreen extends StatefulWidget {
  final Lesson? lesson;

  const LessonFormScreen({super.key, this.lesson});

  @override
  State<LessonFormScreen> createState() => _LessonFormScreenState();
}

class _LessonFormScreenState extends State<LessonFormScreen> {
  final _api = ApiService();
  final _titleCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _videoCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _orderCtrl = TextEditingController(text: '0');
  List<Technique> _techniques = [];
  String? _techniqueId;
  bool _loadingTechniques = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.lesson != null) {
      _titleCtrl.text = widget.lesson!.title;
      _slugCtrl.text = widget.lesson!.slug;
      _videoCtrl.text = widget.lesson!.videoUrl ?? '';
      _contentCtrl.text = widget.lesson!.content ?? '';
      _orderCtrl.text = widget.lesson!.orderIndex.toString();
      _techniqueId = widget.lesson!.techniqueId;
    }
    _loadTechniques();
  }

  Future<void> _loadTechniques() async {
    try {
      final list = await _api.getTechniques();
      setState(() {
        _techniques = list;
        _loadingTechniques = false;
        if (_techniqueId == null && widget.lesson != null) _techniqueId = widget.lesson!.techniqueId;
      });
    } catch (_) {
      setState(() => _loadingTechniques = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _slugCtrl.dispose();
    _videoCtrl.dispose();
    _contentCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _slugCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Título e slug são obrigatórios');
      return;
    }
    if (_techniqueId == null) {
      setState(() => _error = 'Selecione uma técnica');
      return;
    }
    final orderIndex = int.tryParse(_orderCtrl.text) ?? 0;
    setState(() { _saving = true; _error = null; });
    try {
      if (widget.lesson == null) {
        await _api.createLesson(
          techniqueId: _techniqueId!,
          title: _titleCtrl.text.trim(),
          slug: _slugCtrl.text.trim(),
          videoUrl: _videoCtrl.text.trim().isEmpty ? null : _videoCtrl.text.trim(),
          content: _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
          orderIndex: orderIndex,
        );
      } else {
        await _api.updateLesson(
          widget.lesson!.id,
          techniqueId: _techniqueId,
          title: _titleCtrl.text.trim(),
          slug: _slugCtrl.text.trim(),
          videoUrl: _videoCtrl.text.trim().isEmpty ? null : _videoCtrl.text.trim(),
          content: _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
          orderIndex: orderIndex,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo')));
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      setState(() { _error = e.message; _saving = false; });
    } catch (_) {
      setState(() {
        _error = 'Erro de conexão. A API está rodando em ${_api.baseUrl}?';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson == null ? 'Nova lição' : 'Editar lição'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loadingTechniques) const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
            else
              DropdownButtonFormField<String>(
                value: _techniqueId,
                decoration: const InputDecoration(labelText: 'Técnica'),
                items: _techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                onChanged: (v) => setState(() => _techniqueId = v),
              ),
            const SizedBox(height: 16),
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 16),
            TextField(controller: _slugCtrl, decoration: const InputDecoration(labelText: 'Slug')),
            const SizedBox(height: 16),
            TextField(controller: _videoCtrl, decoration: const InputDecoration(labelText: 'URL do vídeo'), keyboardType: TextInputType.url),
            const SizedBox(height: 16),
            TextField(controller: _contentCtrl, decoration: const InputDecoration(labelText: 'Conteúdo (opcional)'), maxLines: 3),
            const SizedBox(height: 16),
            TextField(controller: _orderCtrl, decoration: const InputDecoration(labelText: 'Ordem'), keyboardType: TextInputType.number),
            if (_error != null) ...[const SizedBox(height: 16), Text(_error!, style: const TextStyle(color: Colors.red))],
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Salvar')),
          ],
        ),
      ),
    );
  }
}
