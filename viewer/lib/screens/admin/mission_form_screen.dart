import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/mission.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/form_utils.dart';

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
  DateTime? _startDate;
  DateTime? _endDate;
  String? _techniqueId;
  String? _academyId;
  String _level = 'beginner';
  int _multiplier = 1;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    final firstDate = DateTime(2020);
    final lastDate = DateTime(2100);
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: current ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        _startDateCtrl.text = toBrDate(picked);
      } else {
        _endDate = picked;
        _endDateCtrl.text = toBrDate(picked);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final end = now.add(const Duration(days: 6));
    if (widget.mission != null) {
      _techniqueId = widget.mission!.techniqueId;
      _academyId = widget.mission!.academyId;
      _startDate = parseApiDate(widget.mission!.startDate) ?? now;
      _endDate = parseApiDate(widget.mission!.endDate) ?? end;
      _startDateCtrl.text = toBrDate(_startDate!);
      _endDateCtrl.text = toBrDate(_endDate!);
      _level = widget.mission!.level;
      _themeCtrl.text = widget.mission!.theme ?? '';
      _multiplier = widget.mission!.multiplier;
    } else {
      _startDate = now;
      _endDate = end;
      _startDateCtrl.text = toBrDate(now);
      _endDateCtrl.text = toBrDate(end);
    }
    _multiplierCtrl.text = _multiplier.toString();
    _load();
  }

  Future<void> _load() async {
    try {
      final academies = await _api.getAcademies();
      if (!mounted) return;
      setState(() {
        _academies = academies;
        _loading = false;
        if (_techniqueId == null && widget.mission != null)
          _techniqueId = widget.mission!.techniqueId;
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
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Selecione as datas de início e fim');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(() =>
          _error = 'A data fim deve ser igual ou posterior à data início');
      return;
    }
    final startDate = toApiDate(_startDate!);
    final endDate = toApiDate(_endDate!);
    final mult = int.tryParse(_multiplierCtrl.text.trim());
    final multVal = (mult != null && mult >= 1) ? mult : 1;
    setState(() {
      _saving = true;
      _error = null;
    });
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Salvo')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = userFacingMessage(e);
          _saving = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mission == null ? 'Nova missão' : 'Editar missão'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _academyId,
                    decoration: const InputDecoration(
                        labelText: 'Academia (para escolher técnica)'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Global')),
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
                      hintText: _academyId == null
                          ? 'Selecione academia primeiro'
                          : null,
                    ),
                    items: _techniques
                        .map((t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _techniqueId = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _startDateCtrl,
                    readOnly: true,
                    onTap: () => _pickDate(isStart: true),
                    decoration: const InputDecoration(
                      labelText: 'Início',
                      hintText: 'dd/MM/aaaa',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _endDateCtrl,
                    readOnly: true,
                    onTap: () => _pickDate(isStart: false),
                    decoration: const InputDecoration(
                      labelText: 'Fim',
                      hintText: 'dd/MM/aaaa',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _level,
                    decoration: const InputDecoration(labelText: 'Nível'),
                    items: const [
                      DropdownMenuItem(
                          value: 'beginner', child: Text('Iniciante')),
                      DropdownMenuItem(
                          value: 'intermediate', child: Text('Intermediário')),
                      DropdownMenuItem(
                          value: 'advanced', child: Text('Avançado')),
                    ],
                    onChanged: (v) => setState(() => _level = v ?? 'beginner'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _themeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Tema (opcional)')),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _multiplierCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Multiplicador',
                      hintText: '1',
                      helperText:
                          'Pontos ao concluir = multiplicador × faixa do usuário',
                    ),
                  ),
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
