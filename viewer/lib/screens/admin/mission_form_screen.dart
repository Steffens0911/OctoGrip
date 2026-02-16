import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/mission.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/services/api_service.dart';

class MissionFormScreen extends StatefulWidget {
  final Mission? mission;

  const MissionFormScreen({super.key, this.mission});

  @override
  State<MissionFormScreen> createState() => _MissionFormScreenState();
}

class _MissionFormScreenState extends State<MissionFormScreen> {
  final _api = ApiService();
  final _themeCtrl = TextEditingController();
  final _multiplierCtrl = TextEditingController();
  List<Technique> _techniques = [];
  List<Academy> _academies = [];
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();
  String? _techniqueId;
  String? _academyId;
  String _level = 'beginner';
  int _multiplier = 1;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final startStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final end = now.add(const Duration(days: 6));
    final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    if (widget.mission != null) {
      _techniqueId = widget.mission!.techniqueId;
      _academyId = widget.mission!.academyId;
      _startDateCtrl.text = widget.mission!.startDate;
      _endDateCtrl.text = widget.mission!.endDate;
      _level = widget.mission!.level;
      _themeCtrl.text = widget.mission!.theme ?? '';
      _multiplier = widget.mission!.multiplier;
    } else {
      _startDateCtrl.text = startStr;
      _endDateCtrl.text = endStr;
    }
    _multiplierCtrl.text = _multiplier.toString();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_api.getTechniques(), _api.getAcademies()]);
      setState(() {
        _techniques = results[0] as List<Technique>;
        _academies = results[1] as List<Academy>;
        _loading = false;
        if (_techniqueId == null && widget.mission != null) _techniqueId = widget.mission!.techniqueId;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _themeCtrl.dispose();
    _multiplierCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_techniqueId == null) {
      setState(() => _error = 'Selecione uma técnica');
      return;
    }
    final startDate = _startDateCtrl.text.trim();
    final endDate = _endDateCtrl.text.trim();
    if (startDate.isEmpty || endDate.isEmpty) {
      setState(() => _error = 'Preencha início e fim');
      return;
    }
    final mult = int.tryParse(_multiplierCtrl.text.trim());
    final multVal = (mult != null && mult >= 1) ? mult : 1;
    setState(() { _saving = true; _error = null; });
    try {
      if (widget.mission == null) {
        await _api.createMission(
          techniqueId: _techniqueId!,
          startDate: startDate,
          endDate: endDate,
          level: _level,
          theme: _themeCtrl.text.trim().isEmpty ? null : _themeCtrl.text.trim(),
          academyId: _academyId,
          multiplier: multVal,
        );
      } else {
        await _api.updateMission(
          widget.mission!.id,
          techniqueId: _techniqueId,
          startDate: startDate,
          endDate: endDate,
          level: _level,
          theme: _themeCtrl.text.trim().isEmpty ? null : _themeCtrl.text.trim(),
          academyId: _academyId,
          multiplier: multVal,
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
        title: Text(widget.mission == null ? 'Nova missão' : 'Editar missão'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _techniqueId,
                    decoration: const InputDecoration(labelText: 'Técnica'),
                    items: _techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                    onChanged: (v) => setState(() => _techniqueId = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _startDateCtrl,
                    decoration: const InputDecoration(labelText: 'Início (YYYY-MM-DD)'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _endDateCtrl,
                    decoration: const InputDecoration(labelText: 'Fim (YYYY-MM-DD)'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _level,
                    decoration: const InputDecoration(labelText: 'Nível'),
                    items: const [
                      DropdownMenuItem(value: 'beginner', child: Text('Iniciante')),
                      DropdownMenuItem(value: 'intermediate', child: Text('Intermediário')),
                      DropdownMenuItem(value: 'advanced', child: Text('Avançado')),
                    ],
                    onChanged: (v) => setState(() => _level = v ?? 'beginner'),
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: _themeCtrl, decoration: const InputDecoration(labelText: 'Tema (opcional)')),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _multiplierCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Multiplicador',
                      hintText: '1',
                      helperText: 'Pontos ao concluir = multiplicador × faixa do usuário',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _academyId,
                    decoration: const InputDecoration(labelText: 'Academia (opcional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Global')),
                      ..._academies.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setState(() => _academyId = v),
                  ),
                  if (_error != null) ...[const SizedBox(height: 16), Text(_error!, style: const TextStyle(color: Colors.red))],
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Salvar')),
                ],
              ),
            ),
    );
  }
}
