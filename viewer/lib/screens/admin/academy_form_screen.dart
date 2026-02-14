import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/services/api_service.dart';

class AcademyFormScreen extends StatefulWidget {
  final Academy? academy;

  const AcademyFormScreen({super.key, this.academy});

  @override
  State<AcademyFormScreen> createState() => _AcademyFormScreenState();
}

class _AcademyFormScreenState extends State<AcademyFormScreen> {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  List<Technique> _techniques = [];
  String? _weeklyTechniqueId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.academy != null) {
      _nameCtrl.text = widget.academy!.name;
      _slugCtrl.text = widget.academy!.slug ?? '';
      _weeklyTechniqueId = widget.academy!.weeklyTechniqueId;
    }
    _loadTechniques();
  }

  Future<void> _loadTechniques() async {
    try {
      final list = await _api.getTechniques();
      if (mounted) setState(() {
        _techniques = list;
        _loading = false;
        if (_weeklyTechniqueId == null && widget.academy?.weeklyTechniqueId != null) {
          _weeklyTechniqueId = widget.academy!.weeklyTechniqueId;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nome é obrigatório');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.academy == null) {
        await _api.createAcademy(
          name: _nameCtrl.text.trim(),
          slug: _slugCtrl.text.trim().isEmpty ? null : _slugCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Academia criada')));
          Navigator.pop(context);
        }
      } else {
        await _api.updateAcademy(
          widget.academy!.id,
          name: _nameCtrl.text.trim(),
          slug: _slugCtrl.text.trim().isEmpty ? null : _slugCtrl.text.trim(),
          weeklyTechniqueId: _weeklyTechniqueId,
        );
        if (mounted) {
          final msg = _weeklyTechniqueId != null
              ? 'Academia atualizada. Missão do dia definida para todos os alunos.'
              : 'Academia atualizada';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          Navigator.pop(context);
        }
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().contains('TimeoutException')
            ? 'A requisição expirou (15 s). Verifique se a API está em ${_api.baseUrl}'
            : 'Erro de conexão. A API está rodando em ${_api.baseUrl}?';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.academy != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar academia' : 'Nova academia'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _slugCtrl,
                    decoration: const InputDecoration(labelText: 'Slug (opcional)'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _weeklyTechniqueId,
                    decoration: const InputDecoration(
                      labelText: 'Tema da semana (missão do dia)',
                      hintText: 'Selecione a técnica para todos os alunos',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                      ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                    ],
                    onChanged: (v) => setState(() => _weeklyTechniqueId = v),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A técnica selecionada aparecerá como missão do dia para todos os alunos desta academia.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Salvar'),
                  ),
                ],
              ),
            ),
    );
  }
}
