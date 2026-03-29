import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class LessonFormScreen extends StatefulWidget {
  final Lesson? lesson;

  const LessonFormScreen({super.key, this.lesson});

  @override
  State<LessonFormScreen> createState() => _LessonFormScreenState();
}

class _LessonFormScreenState extends State<LessonFormScreen> {
  final _api = ApiService();
  final _titleCtrl = TextEditingController();
  final _videoCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _orderCtrl = TextEditingController(text: '0');
  List<Academy> _academies = [];
  List<Technique> _techniques = [];
  String? _academyId;
  String? _techniqueId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.lesson != null) {
      _titleCtrl.text = widget.lesson!.title;
      _videoCtrl.text = widget.lesson!.videoUrl ?? '';
      _contentCtrl.text = widget.lesson!.content ?? '';
      _orderCtrl.text = widget.lesson!.orderIndex.toString();
      _academyId = widget.lesson!.academyId;
      _techniqueId = widget.lesson!.techniqueId;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final academies = await _api.getAcademies();
      if (!mounted) return;
      setState(() {
        _academies = academies;
        _loading = false;
      });
      if (_academyId != null) await _loadTechniques(_academyId!);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTechniques(String academyId) async {
    try {
      final techniques = await _api.getTechniques(academyId: academyId);
      if (mounted) {
        setState(() {
          _techniques = techniques;
          if (_techniqueId != null &&
              !techniques.any((t) => t.id == _techniqueId)) {
            _techniqueId = null;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _techniques = []);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _videoCtrl.dispose();
    _contentCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Título é obrigatório');
      return;
    }
    if (widget.lesson == null && _academyId == null) {
      setState(() => _error = 'Selecione uma academia');
      return;
    }
    if (_techniqueId == null) {
      setState(() => _error = 'Selecione uma técnica');
      return;
    }
    final orderIndex = int.tryParse(_orderCtrl.text) ?? 0;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.lesson == null) {
        await _api.createLesson(
          techniqueId: _techniqueId!,
          title: _titleCtrl.text.trim(),
          videoUrl:
              _videoCtrl.text.trim().isEmpty ? null : _videoCtrl.text.trim(),
          content: _contentCtrl.text.trim().isEmpty
              ? null
              : _contentCtrl.text.trim(),
          orderIndex: orderIndex,
        );
      } else {
        await _api.updateLesson(
          widget.lesson!.id,
          techniqueId: _techniqueId,
          title: _titleCtrl.text.trim(),
          videoUrl:
              _videoCtrl.text.trim().isEmpty ? null : _videoCtrl.text.trim(),
          content: _contentCtrl.text.trim().isEmpty
              ? null
              : _contentCtrl.text.trim(),
          orderIndex: orderIndex,
        );
      }
      if (mounted) {
        AppFeedback.show(
          context,
          message: 'Salvo',
          type: AppFeedbackType.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppStandardAppBar(
        title: widget.lesson == null ? 'Nova lição' : 'Editar lição',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              const SizedBox(
                  height: 48,
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.primary)))
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _academyId,
                decoration: const InputDecoration(labelText: 'Academia'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('— Selecione academia —')),
                  ..._academies.map((a) =>
                      DropdownMenuItem(value: a.id, child: Text(a.name))),
                ],
                onChanged: (v) async {
                  setState(() {
                    _academyId = v;
                    _techniques = [];
                    _techniqueId = null;
                  });
                  if (v != null) await _loadTechniques(v);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _techniqueId,
                decoration: InputDecoration(
                  labelText: 'Técnica',
                  hintText:
                      _academyId == null ? 'Selecione academia primeiro' : null,
                ),
                items: _techniques
                    .map((t) =>
                        DropdownMenuItem(value: t.id, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setState(() => _techniqueId = v),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 16),
            TextField(
                controller: _videoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Link do YouTube (opcional)'),
                keyboardType: TextInputType.url),
            const SizedBox(height: 16),
            TextField(
                controller: _contentCtrl,
                decoration:
                    const InputDecoration(labelText: 'Conteúdo (opcional)'),
                maxLines: 3),
            const SizedBox(height: 16),
            TextField(
                controller: _orderCtrl,
                decoration: const InputDecoration(labelText: 'Ordem'),
                keyboardType: TextInputType.number),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red))
            ],
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar')),
          ],
        ),
      ),
    );
  }
}
