import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/position.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/screens/admin/academy_points_edit_screen.dart';
import 'package:viewer/screens/admin/position_form_screen.dart';
import 'package:viewer/screens/admin/technique_form_screen.dart';
import 'package:viewer/services/academy_service.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/form_utils.dart';

/// Detalhe da academia: missão do dia (técnica), ranking, dificuldades, relatório semanal.
class AcademyDetailScreen extends StatefulWidget {
  final Academy academy;
  final VoidCallback onUpdated;
  final VoidCallback onDeleted;

  const AcademyDetailScreen({
    super.key,
    required this.academy,
    required this.onUpdated,
    required this.onDeleted,
  });

  @override
  State<AcademyDetailScreen> createState() => _AcademyDetailScreenState();
}

class _AcademyDetailScreenState extends State<AcademyDetailScreen> {
  final AcademyService _service = AcademyService();
  final ApiService _api = ApiService();
  late Academy _academy;
  List<Technique> _techniques = [];
  List<Position> _positions = [];
  String? _weeklyTechniqueId;
  String? _weeklyTechnique2Id;
  String? _weeklyTechnique3Id;
  int _weeklyMultiplier1 = 1;
  int _weeklyMultiplier2 = 1;
  int _weeklyMultiplier3 = 1;
  late final TextEditingController _mult1Controller;
  late final TextEditingController _mult2Controller;
  late final TextEditingController _mult3Controller;
  bool _loadingTechniques = true;
  bool _loadingPositions = true;
  bool _savingTheme = false;
  bool _resetting = false;
  Map<String, dynamic>? _ranking;
  Map<String, dynamic>? _difficulties;
  AcademyWeeklyReport? _weeklyReport;
  bool _loadingExtra = true;
  String? _errorExtra;
  List<Map<String, dynamic>> _trophies = [];
  bool _loadingTrophies = true;

  @override
  void initState() {
    super.initState();
    _academy = widget.academy;
    _weeklyTechniqueId = _academy.weeklyTechniqueId;
    _weeklyTechnique2Id = _academy.weeklyTechnique2Id;
    _weeklyTechnique3Id = _academy.weeklyTechnique3Id;
    _weeklyMultiplier1 = _academy.weeklyMultiplier1;
    _weeklyMultiplier2 = _academy.weeklyMultiplier2;
    _weeklyMultiplier3 = _academy.weeklyMultiplier3;
    _mult1Controller = TextEditingController(text: _weeklyMultiplier1.toString());
    _mult2Controller = TextEditingController(text: _weeklyMultiplier2.toString());
    _mult3Controller = TextEditingController(text: _weeklyMultiplier3.toString());
    _loadTechniques();
    _loadPositions();
    _loadRankingAndReport();
    _loadTrophies();
  }

  @override
  void dispose() {
    _mult1Controller.dispose();
    _mult2Controller.dispose();
    _mult3Controller.dispose();
    super.dispose();
  }

  Future<void> _loadTechniques() async {
    try {
      final list = await _api.getTechniques(academyId: _academy.id);
      if (mounted) setState(() {
        _techniques = list;
        _loadingTechniques = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTechniques = false);
    }
  }

  Future<void> _loadPositions() async {
    try {
      final list = await _api.getPositions(academyId: _academy.id);
      if (mounted) setState(() {
        _positions = list;
        _loadingPositions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPositions = false);
    }
  }

  String _positionName(String id) => _positions.where((p) => p.id == id).map((p) => p.name).firstOrNull ?? id;

  Future<void> _openPositionForm([Position? p]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PositionFormScreen(academyId: _academy.id, position: p),
      ),
    );
    if (mounted) _loadPositions();
  }

  Future<void> _openTechniqueForm([Technique? t]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TechniqueFormScreen(academyId: _academy.id, technique: t),
      ),
    );
    if (mounted) {
      _loadTechniques();
      _loadPositions();
    }
  }

  Future<void> _deletePosition(Position p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir posição'),
        content: Text('Excluir "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deletePosition(p.id, academyId: _academy.id);
      if (mounted) _loadPositions();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posição excluída')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
    }
  }

  Future<void> _deleteTechnique(Technique t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir técnica'),
        content: Text('Excluir "${t.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteTechnique(t.id, academyId: _academy.id);
      if (mounted) _loadTechniques();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Técnica excluída')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
    }
  }

  Future<void> _loadTrophies() async {
    setState(() => _loadingTrophies = true);
    try {
      final list = await _api.getTrophies(_academy.id);
      if (mounted) setState(() {
        _trophies = list;
        _loadingTrophies = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTrophies = false);
    }
  }

  Future<void> _showCreateTrophyDialog() async {
    if (_techniques.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastre técnicas antes de criar troféus.')),
      );
      return;
    }
    final formKey = GlobalKey<FormBuilderState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Criar troféu'),
        content: SingleChildScrollView(
          child: FormBuilder(
            key: formKey,
            initialValue: {
              'name': '',
              'techniqueId': _techniques.first.id,
              'startDate': DateTime.now(),
              'endDate': DateTime.now().add(const Duration(days: 30)),
              'targetCount': '10',
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FormBuilderTextField(
                  name: 'name',
                  decoration: const InputDecoration(
                    labelText: 'Nome do troféu',
                    hintText: 'Ex: Arm Lock',
                  ),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(errorText: 'Nome é obrigatório'),
                  ]),
                ),
                const SizedBox(height: 12),
                FormBuilderDropdown<String>(
                  name: 'techniqueId',
                  decoration: const InputDecoration(labelText: 'Técnica'),
                  items: _techniques
                      .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                      .toList(),
                  initialValue: _techniques.first.id,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(errorText: 'Selecione uma técnica'),
                  ]),
                ),
                const SizedBox(height: 12),
                FormBuilderDateTimePicker(
                  name: 'startDate',
                  inputType: InputType.date,
                  format: brDateFormat,
                  locale: const Locale('pt', 'BR'),
                  decoration: const InputDecoration(
                    labelText: 'Data início',
                    hintText: 'dd/MM/aaaa',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(errorText: 'Data início é obrigatória'),
                  ]),
                ),
                const SizedBox(height: 8),
                FormBuilderDateTimePicker(
                  name: 'endDate',
                  inputType: InputType.date,
                  format: brDateFormat,
                  locale: const Locale('pt', 'BR'),
                  decoration: const InputDecoration(
                    labelText: 'Data fim',
                    hintText: 'dd/MM/aaaa',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(errorText: 'Data fim é obrigatória'),
                  ]),
                ),
                const SizedBox(height: 8),
                FormBuilderTextField(
                  name: 'targetCount',
                  decoration: const InputDecoration(labelText: 'Meta de execuções (ex: 10)'),
                  keyboardType: TextInputType.number,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(errorText: 'Meta é obrigatória'),
                    FormBuilderValidators.integer(errorText: 'Deve ser um número inteiro'),
                    FormBuilderValidators.min(1, errorText: 'Meta deve ser pelo menos 1'),
                  ]),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.saveAndValidate() ?? false) {
                final values = formKey.currentState!.value;
                final name = values['name'] as String;
                final techniqueId = values['techniqueId'] as String;
                final startDateValue = values['startDate'] as DateTime;
                final endDateValue = values['endDate'] as DateTime;
                if (endDateValue.isBefore(startDateValue)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('A data fim deve ser igual ou posterior à data início.')),
                  );
                  return;
                }
                final targetCount = int.parse(values['targetCount'] as String);
                final startDate = toApiDate(startDateValue);
                final endDate = toApiDate(endDateValue);
                
                Navigator.pop(ctx);
                try {
                  await _api.createTrophy(
                    academyId: _academy.id,
                    techniqueId: techniqueId,
                    name: name.trim(),
                    startDate: startDate,
                    endDate: endDate,
                    targetCount: targetCount,
                  );
                  if (mounted) {
                    _loadTrophies();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Troféu criado. Alunos podem conquistar ouro, prata ou bronze.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(userFacingMessage(e))),
                    );
                  }
                }
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRankingAndReport() async {
    setState(() {
      _loadingExtra = true;
      _errorExtra = null;
    });
    try {
      final ranking = await _service.getRanking(_academy.id);
      final difficulties = await _service.getDifficulties(_academy.id);
      final report = await _service.getWeeklyReport(_academy.id);
      if (mounted) setState(() {
        _ranking = ranking;
        _difficulties = difficulties;
        _weeklyReport = report;
        _loadingExtra = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _errorExtra = userFacingMessage(e);
        _loadingExtra = false;
      });
    }
  }

  Future<void> _saveTheme() async {
    setState(() => _savingTheme = true);
    try {
      final updated = await _service.updateWeeklyMissions(
        _academy.id,
        weeklyTechniqueId: _weeklyTechniqueId,
        weeklyTechnique2Id: _weeklyTechnique2Id,
        weeklyTechnique3Id: _weeklyTechnique3Id,
        weeklyMultiplier1: _weeklyMultiplier1,
        weeklyMultiplier2: _weeklyMultiplier2,
        weeklyMultiplier3: _weeklyMultiplier3,
      );
      if (updated != null && mounted) {
        setState(() {
          _academy = updated;
          _weeklyTechniqueId = updated.weeklyTechniqueId;
          _weeklyTechnique2Id = updated.weeklyTechnique2Id;
          _weeklyTechnique3Id = updated.weeklyTechnique3Id;
          _weeklyMultiplier1 = updated.weeklyMultiplier1;
          _weeklyMultiplier2 = updated.weeklyMultiplier2;
          _weeklyMultiplier3 = updated.weeklyMultiplier3;
          _mult1Controller.text = _weeklyMultiplier1.toString();
          _mult2Controller.text = _weeklyMultiplier2.toString();
          _mult3Controller.text = _weeklyMultiplier3.toString();
          _savingTheme = false;
        });
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_weeklyTechniqueId != null || _weeklyTechnique2Id != null || _weeklyTechnique3Id != null
                ? 'Missões semanais atualizadas para todos os alunos.'
                : 'Tema salvo.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingTheme = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  Future<void> _resetMissions() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar missões'),
        content: const Text(
          'Reiniciar missões desta academia? Todos poderão fazer as posições novamente. '
          'A pontuação já conquistada será preservada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _resetting = true);
    try {
      final result = await _service.resetMissions(_academy.id);
      if (mounted) {
        setState(() => _resetting = false);
        final msg = result['message'] as String? ?? 'Missões reiniciadas. Pontuação preservada.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.primary),
        );
        _loadRankingAndReport();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _resetting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir academia?'),
        content: Text(
            'Remover "${_academy.name}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.delete(_academy.id);
      if (mounted) widget.onDeleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_academy.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final nameController = TextEditingController(text: _academy.name);
              String? techniqueId = _academy.weeklyTechniqueId;
              await showDialog<void>(
                context: context,
                builder: (ctx) => StatefulBuilder(
                  builder: (context, setDialogState) => AlertDialog(
                    title: const Text('Editar academia'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(labelText: 'Nome'),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: techniqueId,
                            decoration: const InputDecoration(labelText: 'Missão do dia (técnica)'),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                              ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                            ],
                            onChanged: (v) => setDialogState(() => techniqueId = v),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;
                          Navigator.pop(ctx);
                          try {
                            final updated = await _service.update(
                              _academy.id,
                              name: name,
                              weeklyTechniqueId: techniqueId,
                            );
                            if (updated != null && mounted) {
                              setState(() {
                                _academy = updated;
                                _weeklyTechniqueId = updated.weeklyTechniqueId;
                              });
                              widget.onUpdated();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(userFacingMessage(e))),
                              );
                            }
                          }
                        },
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _confirmDelete();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Excluir academia',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadRankingAndReport();
          _loadTechniques();
          _loadPositions();
          _loadTrophies();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(AppTheme.screenPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                    child: const Icon(Icons.edit_note, color: AppTheme.primary),
                  ),
                  title: const Text('Editar pontos dos alunos', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Ajustar pontuação manual dos alunos desta academia'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AcademyPointsEditScreen(
                        academyId: _academy.id,
                        academyName: _academy.name,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SectionTitle(title: 'Posições'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Posições desta academia',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => _openPositionForm(),
                            tooltip: 'Nova posição',
                          ),
                        ],
                      ),
                      if (_loadingPositions)
                        const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                      else if (_positions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Nenhuma posição. Adicione posições para criar técnicas.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _positions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final p = _positions[i];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(p.name),
                              subtitle: p.description != null && p.description!.isNotEmpty ? Text(p.description!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                              trailing: AuthService().canEditResources() ? Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(icon: const Icon(Icons.edit, size: 20, color: AppTheme.primary), onPressed: () => _openPositionForm(p)),
                                IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () => _deletePosition(p)),
                              ]) : null,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SectionTitle(title: 'Técnicas'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Técnicas desta academia',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (AuthService().canEditResources())
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _openTechniqueForm(),
                              tooltip: 'Nova técnica',
                            ),
                        ],
                      ),
                      if (_loadingTechniques)
                        const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                      else if (_techniques.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Nenhuma técnica. Adicione posições primeiro, depois crie técnicas.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _techniques.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final t = _techniques[i];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(t.name),
                              subtitle: Text(
                                '${_positionName(t.fromPositionId)} → ${_positionName(t.toPositionId)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: AuthService().canEditResources() ? Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(icon: const Icon(Icons.edit, size: 20, color: AppTheme.primary), onPressed: () => _openTechniqueForm(t)),
                                IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () => _deleteTechnique(t)),
                              ]) : null,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SectionTitle(title: 'Troféus'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Troféus desta academia (ouro/prata/bronze por execuções)',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (AuthService().canEditResources())
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _showCreateTrophyDialog,
                              tooltip: 'Criar troféu',
                            ),
                        ],
                      ),
                      if (_loadingTrophies)
                        const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                      else if (_trophies.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Nenhum troféu. Crie um troféu vinculado a uma técnica, com período e meta de execuções.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _trophies.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final t = _trophies[i];
                            final name = t['name'] as String? ?? '—';
                            final techniqueName = t['technique_name'] as String? ?? '';
                            final start = t['start_date'] as String? ?? '';
                            final end = t['end_date'] as String? ?? '';
                            final target = t['target_count'] as int? ?? 0;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.emoji_events_outlined, color: AppTheme.primary, size: 24),
                              title: Text(name),
                              subtitle: Text(
                                '${techniqueName.isNotEmpty ? techniqueName : 'Técnica'} · $start a $end · Meta: $target',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Missões semanais (3 técnicas)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'As técnicas selecionadas aparecem como missões no painel do aluno enquanto estiverem configuradas.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      if (_loadingTechniques)
                        const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                      else ...[
                        DropdownButtonFormField<String>(
                          value: _weeklyTechniqueId,
                          decoration: const InputDecoration(
                            labelText: 'Missão 1',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                            ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                          ],
                          onChanged: (v) => setState(() => _weeklyTechniqueId = v),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _weeklyTechnique2Id,
                          decoration: const InputDecoration(
                            labelText: 'Missão 2',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                            ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                          ],
                          onChanged: (v) => setState(() => _weeklyTechnique2Id = v),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _weeklyTechnique3Id,
                          decoration: const InputDecoration(
                            labelText: 'Missão 3',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                            ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                          ],
                          onChanged: (v) => setState(() => _weeklyTechnique3Id = v),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Pontuação base (por slot)',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = AppTheme.isNarrow(context);
                            final fields = [
                              TextFormField(
                                controller: _mult1Controller,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Missão 1',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) {
                                  final n = int.tryParse(v);
                                  if (n != null && n >= 1) setState(() => _weeklyMultiplier1 = n);
                                },
                              ),
                              TextFormField(
                                controller: _mult2Controller,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Missão 2',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) {
                                  final n = int.tryParse(v);
                                  if (n != null && n >= 1) setState(() => _weeklyMultiplier2 = n);
                                },
                              ),
                              TextFormField(
                                controller: _mult3Controller,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Missão 3',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) {
                                  final n = int.tryParse(v);
                                  if (n != null && n >= 1) setState(() => _weeklyMultiplier3 = n);
                                },
                              ),
                            ];
                            if (narrow) {
                              return Column(
                                children: fields
                                    .map((f) => Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: f,
                                        ))
                                    .toList(),
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: fields[0]),
                                const SizedBox(width: 12),
                                Expanded(child: fields[1]),
                                const SizedBox(width: 12),
                                Expanded(child: fields[2]),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pontos ao confirmar = pontuação base do slot × faixa do oponente.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = AppTheme.isNarrow(context);
                          final saveBtn = FilledButton.icon(
                            onPressed: _savingTheme ? null : _saveTheme,
                            icon: _savingTheme
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_savingTheme ? 'Salvando...' : 'Salvar missões semanais'),
                          );
                          final resetBtn = OutlinedButton.icon(
                            onPressed: _resetting ? null : _resetMissions,
                            icon: _resetting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh),
                            label: Text(_resetting ? 'Reiniciando...' : 'Reiniciar missões'),
                          );
                          if (narrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                saveBtn,
                                const SizedBox(height: 8),
                                resetBtn,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: saveBtn),
                              const SizedBox(width: 12),
                              Expanded(child: resetBtn),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_loadingExtra)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorExtra != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.grey.shade600),
                      const SizedBox(height: 8),
                      Text(_errorExtra!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _loadRankingAndReport,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              else ...[
                _SectionTitle(title: 'Ranking (últimos 30 dias)'),
                Card(
                  child: _ranking != null &&
                          (_ranking!['entries'] as List).isNotEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount:
                              (_ranking!['entries'] as List).length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = (_ranking!['entries'] as List)[i]
                                as AcademyRankingEntry;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary
                                    .withValues(alpha: 0.2),
                                child: Text(
                                  '${e.rank}',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(e.name ?? 'Sem nome'),
                              trailing: Text(
                                '${e.completionsCount} conclusões',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        )
                      : const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Nenhuma conclusão no período.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                _SectionTitle(title: 'Dificuldades reportadas'),
                Card(
                  child: _difficulties != null &&
                          (_difficulties!['entries'] as List).isNotEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount:
                              (_difficulties!['entries'] as List).length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = (_difficulties!['entries'] as List)[i]
                                as AcademyDifficultyEntry;
                            return ListTile(
                              title: Text(e.positionName),
                              trailing: Text(
                                '${e.count} reportes',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        )
                      : const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Nenhuma dificuldade reportada.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                _SectionTitle(title: 'Relatório semanal'),
                Card(
                  child: _weeklyReport != null
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_weeklyReport!.weekStart} a ${_weeklyReport!.weekEnd}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_weeklyReport!.completionsCount} conclusões · '
                                '${_weeklyReport!.activeUsersCount} ativos',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if (_weeklyReport!.entries.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Divider(),
                                ..._weeklyReport!.entries.map((e) => ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Text(
                                        '${e.rank}º',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      title: Text(e.name ?? 'Sem nome'),
                                      trailing: Text(
                                        '${e.completionsCount}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    )),
                              ],
                            ],
                          ),
                        )
                      : const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Sem dados da semana.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
