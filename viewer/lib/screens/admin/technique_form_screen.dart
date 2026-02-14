import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/models/position.dart';
import 'package:viewer/services/api_service.dart';

class TechniqueFormScreen extends StatefulWidget {
  final Technique? technique;

  const TechniqueFormScreen({super.key, this.technique});

  @override
  State<TechniqueFormScreen> createState() => _TechniqueFormScreenState();
}

class _TechniqueFormScreenState extends State<TechniqueFormScreen> {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _videoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<Position> _positions = [];
  String? _fromPositionId;
  String? _toPositionId;
  bool _loadingPositions = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.technique != null) {
      _nameCtrl.text = widget.technique!.name;
      _videoCtrl.text = widget.technique!.videoUrl ?? '';
      _descCtrl.text = widget.technique!.description ?? '';
      _fromPositionId = widget.technique!.fromPositionId;
      _toPositionId = widget.technique!.toPositionId;
    }
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    try {
      final list = await _api.getPositions();
      setState(() {
        _positions = list;
        _loadingPositions = false;
        if (_fromPositionId == null && widget.technique != null) _fromPositionId = widget.technique!.fromPositionId;
        if (_toPositionId == null && widget.technique != null) _toPositionId = widget.technique!.toPositionId;
      });
    } catch (_) {
      setState(() => _loadingPositions = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _videoCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nome é obrigatório');
      return;
    }
    if (_fromPositionId == null || _toPositionId == null) {
      setState(() => _error = 'Selecione de/para posição');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      if (widget.technique == null) {
        await _api.createTechnique(
          name: _nameCtrl.text.trim(),
          videoUrl: _videoCtrl.text.trim().isEmpty ? null : _videoCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          fromPositionId: _fromPositionId!,
          toPositionId: _toPositionId!,
        );
      } else {
        await _api.updateTechnique(
          widget.technique!.id,
          name: _nameCtrl.text.trim(),
          videoUrl: _videoCtrl.text.trim().isEmpty ? null : _videoCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          fromPositionId: _fromPositionId,
          toPositionId: _toPositionId,
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
        title: Text(widget.technique == null ? 'Nova técnica' : 'Editar técnica'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nome')),
            const SizedBox(height: 16),
            TextField(controller: _videoCtrl, decoration: const InputDecoration(labelText: 'Link do YouTube (opcional)'), keyboardType: TextInputType.url),
            const SizedBox(height: 16),
            if (_loadingPositions) const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
            else ...[
              DropdownButtonFormField<String>(
                value: _fromPositionId,
                decoration: const InputDecoration(labelText: 'De posição'),
                items: _positions.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (v) => setState(() => _fromPositionId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _toPositionId,
                decoration: const InputDecoration(labelText: 'Para posição'),
                items: _positions.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (v) => setState(() => _toPositionId = v),
              ),
            ],
            const SizedBox(height: 16),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descrição (opcional)'), maxLines: 2),
            if (_error != null) ...[const SizedBox(height: 16), Text(_error!, style: const TextStyle(color: Colors.red))],
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Salvar')),
          ],
        ),
      ),
    );
  }
}
