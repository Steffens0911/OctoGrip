import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/services/academy_service.dart';
import 'package:viewer/services/api_service.dart';

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
  String? _weeklyTechniqueId;
  String? _weeklyTechnique2Id;
  String? _weeklyTechnique3Id;
  bool _loadingTechniques = true;
  bool _savingTheme = false;
  Map<String, dynamic>? _ranking;
  Map<String, dynamic>? _difficulties;
  AcademyWeeklyReport? _weeklyReport;
  bool _loadingExtra = true;
  String? _errorExtra;

  @override
  void initState() {
    super.initState();
    _academy = widget.academy;
    _weeklyTechniqueId = _academy.weeklyTechniqueId;
    _weeklyTechnique2Id = _academy.weeklyTechnique2Id;
    _weeklyTechnique3Id = _academy.weeklyTechnique3Id;
    _loadTechniques();
    _loadRankingAndReport();
  }

  Future<void> _loadTechniques() async {
    try {
      final list = await _api.getTechniques();
      if (mounted) setState(() {
        _techniques = list;
        _loadingTechniques = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTechniques = false);
    }
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
      setState(() {
        _ranking = ranking;
        _difficulties = difficulties;
        _weeklyReport = report;
        _loadingExtra = false;
      });
    } catch (e) {
      setState(() {
        _errorExtra = e.toString().replaceFirst('AcademyServiceException: ', '');
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
      );
      if (updated != null && mounted) {
        setState(() {
          _academy = updated;
          _weeklyTechniqueId = updated.weeklyTechniqueId;
          _weeklyTechnique2Id = updated.weeklyTechnique2Id;
          _weeklyTechnique3Id = updated.weeklyTechnique3Id;
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
          SnackBar(content: Text(e.toString())),
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
          SnackBar(content: Text(e.toString())),
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
              final slugController = TextEditingController(text: _academy.slug ?? '');
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
                          TextField(
                            controller: slugController,
                            decoration: const InputDecoration(labelText: 'Slug (opcional)'),
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
                              slug: slugController.text.trim().isEmpty ? null : slugController.text.trim(),
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
                                SnackBar(content: Text(e.toString())),
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
        onRefresh: _loadRankingAndReport,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_academy.slug != null && _academy.slug!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _academy.slug!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
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
                        'Seg–ter, qua–qui e sex–dom: cada técnica aparece como missão do dia nesse período.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      if (_loadingTechniques)
                        const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                      else ...[
                        DropdownButtonFormField<String>(
                          value: _weeklyTechniqueId,
                          decoration: const InputDecoration(
                            labelText: 'Missão 1 (seg–ter)',
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
                            labelText: 'Missão 2 (qua–qui)',
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
                            labelText: 'Missão 3 (sex–dom)',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                            ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                          ],
                          onChanged: (v) => setState(() => _weeklyTechnique3Id = v),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _savingTheme ? null : _saveTheme,
                          icon: _savingTheme
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(_savingTheme ? 'Salvando...' : 'Salvar missões semanais'),
                        ),
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
