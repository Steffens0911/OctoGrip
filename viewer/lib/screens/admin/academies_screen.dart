import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/screens/admin/academy_detail_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

/// Lista e CRUD de academias (seção professor).
class AcademiesScreen extends StatefulWidget {
  const AcademiesScreen({super.key});

  @override
  State<AcademiesScreen> createState() => _AcademiesScreenState();
}

class _AcademiesScreenState extends State<AcademiesScreen> {
  final ApiService _api = ApiService();
  List<Academy> _list = [];
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
      final list = await _api.getAcademies();
      if (mounted) {
        setState(() {
        _list = list;
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _error = userFacingMessage(e);
        _loading = false;
      });
      }
    }
  }

  Future<void> _delete(Academy a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir academia?'),
        content: Text('Remover "${a.name}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteAcademy(a.id);
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  Future<void> _openForm({Academy? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final isEdit = existing != null;
    List<Technique> techniques = [];
    if (isEdit) {
      try {
        techniques = await _api.getTechniques(academyId: existing.id);
      } catch (_) {}
    }
    String? selectedTechniqueId = existing?.weeklyTechniqueId;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Editar academia' : 'Nova academia'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    hintText: 'Nome da academia',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                if (isEdit) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTechniqueId,
                    decoration: const InputDecoration(
                      labelText: 'Missão do dia (técnica)',
                      hintText: 'Tema da semana = técnica para os alunos',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                      ...techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                    ],
                    onChanged: (v) => setDialogState(() => selectedTechniqueId = v),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'A técnica selecionada será a missão do dia para todos os alunos.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
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
                if (name.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Informe o nome da academia.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  if (isEdit) {
                    await _api.updateAcademy(
                      existing.id,
                      name: name,
                      weeklyTechniqueId: selectedTechniqueId,
                    );
                  } else {
                    await _api.createAcademy(name: name);
                  }
                  if (mounted) _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(userFacingMessage(e))),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Salvar' : 'Criar'),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(Academy a) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (ctx) => AcademyDetailScreen(
          academy: a,
          onUpdated: _load,
          onDeleted: () {
            Navigator.pop(ctx);
            _load();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.textMutedOf(context)),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondaryOf(context)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 64, color: AppTheme.textMutedOf(context)),
              const SizedBox(height: 16),
              Text(
                'Nenhuma academia cadastrada.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Toque no + para adicionar uma academia.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: EdgeInsets.all(AppTheme.screenPadding(context)),
          itemCount: _list.length,
          itemBuilder: (context, index) {
            final a = _list[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                  child: const Icon(Icons.school, color: AppTheme.primary),
                ),
                title: Text(a.name),
                subtitle: Text(
                  [
                    if (a.slug != null && a.slug!.isNotEmpty) a.slug,
                    a.weeklyTechniqueName ?? a.weeklyTheme,
                  ].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _openForm(existing: a);
                    if (value == 'delete') _delete(a);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Editar'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
leading: Icon(Icons.delete, color: Theme.of(ctx).colorScheme.error),
                title: Text('Excluir', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                      ),
                    ),
                  ],
                ),
                onTap: () => _openDetail(a),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
