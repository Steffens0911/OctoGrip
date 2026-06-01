import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/models/manual_trophy.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/services/api_service.dart';

/// Dialog para o professor indicar um aluno para um troféu/medalha.
class AwardTrophyDialog extends StatefulWidget {
  const AwardTrophyDialog({
    super.key,
    required this.academyId,
    required this.template,
    this.events = const [],
  });

  final String academyId;
  final TrophyTemplate template;
  final List<ChampionshipEvent> events;

  @override
  State<AwardTrophyDialog> createState() => _AwardTrophyDialogState();
}

class _AwardTrophyDialogState extends State<AwardTrophyDialog> {
  final _api = ApiService();
  final _noteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  List<UserModel> _allStudents = [];
  List<UserModel> _filtered = [];
  UserModel? _selectedStudent;

  ChampionshipEvent? _selectedEvent;
  String? _selectedMedalType;

  bool _loadingStudents = true;
  bool _saving = false;
  String? _error;

  bool get _isChampionship => widget.template.isChampionship;

  static const _medalOptions = [
    ('gold', '🥇 Ouro'),
    ('silver', '🥈 Prata'),
    ('bronze', '🥉 Bronze'),
    ('participation', '🎖️ Participação'),
  ];

  static const _tierOptions = [
    ('gold', '🥇 Ouro'),
    ('silver', '🥈 Prata'),
    ('bronze', '🥉 Bronze'),
  ];

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _searchCtrl.addListener(_filterStudents);
    if (_isChampionship && widget.events.isNotEmpty) {
      _selectedEvent = widget.events.first;
      _selectedMedalType = 'gold';
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final raw = await _api.getAcademyStudentsForSelection(widget.academyId);
      final students = raw
          .map(UserModel.fromJson)
          .where((u) => u.role == 'aluno')
          .toList()
        ..sort((a, b) => (a.name ?? a.email).toLowerCase().compareTo(
              (b.name ?? b.email).toLowerCase(),
            ));
      if (!mounted) return;
      setState(() {
        _allStudents = students;
        _filtered = students;
        _loadingStudents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStudents = false;
        _error = 'Erro ao carregar alunos: ${e.toString()}';
      });
    }
  }

  void _filterStudents() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allStudents
          : _allStudents
              .where((u) =>
                  (u.name ?? '').toLowerCase().contains(q) ||
                  u.email.toLowerCase().contains(q))
              .toList();
    });
  }

  bool get _canSave {
    if (_selectedStudent == null) return false;
    if (_isChampionship) {
      return _selectedEvent != null && _selectedMedalType != null;
    }
    return true;
  }

  Future<void> _award() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.awardManualTrophy(
        templateId: widget.template.id,
        userId: _selectedStudent!.id,
        championshipEventId: _isChampionship ? _selectedEvent?.id : null,
        medalType: _selectedMedalType,
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_isChampionship ? '🏅' : '🏆'} ${widget.template.name} concedido a ${_selectedStudent!.name ?? _selectedStudent!.email}!',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst(RegExp(r'^[A-Za-z]+Exception:?\s*'), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                children: [
                  const Icon(Icons.military_tech_rounded, color: AppTheme.primary),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conceder troféu',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          widget.template.name,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.m),
                shrinkWrap: true,
                children: [
                  // Troféu custom: tier opcional (ouro/prata/bronze)
                  if (!_isChampionship) ...[
                    const Text(
                      'Tier (opcional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Wrap(
                      spacing: AppSpacing.s,
                      children: [
                        ChoiceChip(
                          label: const Text('Nenhum'),
                          selected: _selectedMedalType == null,
                          onSelected: (_) => setState(() => _selectedMedalType = null),
                        ),
                        ..._tierOptions.map(((String key, String label) opt) {
                          final selected = _selectedMedalType == opt.$1;
                          return ChoiceChip(
                            label: Text(opt.$2),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _selectedMedalType = opt.$1),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                  ],
                  // Campeonato: seleção de evento e medalha
                  if (_isChampionship) ...[
                    const Text(
                      'Campeonato',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    if (widget.events.isEmpty)
                      const Text(
                        'Nenhum campeonato cadastrado. Cadastre primeiro na aba Campeonatos.',
                        style: TextStyle(color: Colors.red),
                      )
                    else
                      DropdownButtonFormField<ChampionshipEvent>(
                        value: _selectedEvent, // ignore: deprecated_member_use
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: widget.events
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    '${e.name} (${e.eventDate})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedEvent = v),
                      ),
                    const SizedBox(height: AppSpacing.m),
                    const Text(
                      'Medalha',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Wrap(
                      spacing: AppSpacing.s,
                      children: _medalOptions.map(((String key, String label) option) {
                        final selected = _selectedMedalType == option.$1;
                        return ChoiceChip(
                          label: Text(option.$2),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedMedalType = option.$1),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.m),
                  ],
                  // Busca de aluno
                  const Text(
                    'Aluno',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Buscar aluno...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  if (_loadingStudents)
                    const Center(child: CircularProgressIndicator())
                  else if (_filtered.isEmpty)
                    const Text(
                      'Nenhum aluno encontrado.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final u = _filtered[i];
                          final selected = _selectedStudent?.id == u.id;
                          return ListTile(
                            dense: true,
                            selected: selected,
                            selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                              child: Text(
                                (u.name ?? u.email)
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            title: Text(
                              u.name ?? u.email,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: u.graduation != null
                                ? Text(
                                    _graduationLabel(u.graduation!),
                                    style: const TextStyle(fontSize: 12),
                                  )
                                : null,
                            trailing: selected
                                ? const Icon(Icons.check_circle_rounded,
                                    color: AppTheme.primary)
                                : null,
                            onTap: () => setState(() => _selectedStudent = u),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: AppSpacing.m),
                  // Observação
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Observação (opcional)',
                      hintText: 'Ex: Parabéns pela vitória!',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    maxLength: 300,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_canSave && !_saving) ? _award : null,
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.military_tech_rounded),
                  label: const Text('Conceder troféu'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _graduationLabel(String g) {
    const map = {
      'white': 'Branca',
      'blue': 'Azul',
      'purple': 'Roxa',
      'brown': 'Marrom',
      'black': 'Preta',
    };
    return map[g] ?? g;
  }
}
