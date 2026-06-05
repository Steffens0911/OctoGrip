import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/models/manual_trophy.dart';
import 'package:viewer/screens/academy/award_trophy_dialog.dart';
import 'package:viewer/screens/academy/championship_event_form_screen.dart';
import 'package:viewer/screens/academy/manual_trophy_template_form_screen.dart';
import 'package:viewer/services/api_service.dart';
// Hub de troféus manuais: troféus livres e campeonatos.
class ManualTrophiesHubScreen extends StatefulWidget {
  const ManualTrophiesHubScreen({super.key, required this.academyId});
  final String academyId;

  @override
  State<ManualTrophiesHubScreen> createState() => _ManualTrophiesHubScreenState();
}

class _ManualTrophiesHubScreenState extends State<ManualTrophiesHubScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabs;

  List<TrophyTemplate> _customTemplates = [];
  List<TrophyTemplate> _championshipTemplates = [];
  List<ChampionshipEvent> _events = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final customRaw = _api.getManualTrophyTemplates(widget.academyId, trophyType: 'custom');
      final champRaw = _api.getManualTrophyTemplates(widget.academyId, trophyType: 'championship');
      final eventsRaw = _api.getChampionshipEvents(widget.academyId);
      final custom = await customRaw;
      final champ = await champRaw;
      final events = await eventsRaw;
      if (!mounted) return;
      setState(() {
        _customTemplates = custom.map(TrophyTemplate.fromJson).toList();
        _championshipTemplates = champ.map(TrophyTemplate.fromJson).toList();
        _events = events.map(ChampionshipEvent.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst(RegExp(r'^[A-Za-z]+Exception:?\s*'), '');
      });
    }
  }

  // -----------------------------------------------------------------------
  // Ações: Custom
  // -----------------------------------------------------------------------

  Future<void> _newCustomTemplate() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualTrophyTemplateFormScreen(
          academyId: widget.academyId,
          trophyType: 'custom',
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _editCustomTemplate(TrophyTemplate t) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualTrophyTemplateFormScreen(
          academyId: widget.academyId,
          trophyType: 'custom',
          existing: t,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteTemplate(TrophyTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover troféu?'),
        content: Text('Remover "${t.name}" da lista de troféus da academia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteManualTrophyTemplate(t.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _awardCustomTrophy(TrophyTemplate t) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AwardTrophyDialog(
        academyId: widget.academyId,
        template: t,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Ações: Campeonato
  // -----------------------------------------------------------------------

  Future<void> _newChampionshipTemplate() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualTrophyTemplateFormScreen(
          academyId: widget.academyId,
          trophyType: 'championship',
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _newEvent() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChampionshipEventFormScreen(academyId: widget.academyId),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteEvent(ChampionshipEvent e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover campeonato?'),
        content: Text('Remover "${e.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteChampionshipEvent(e.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _awardChampionshipMedal(TrophyTemplate t) async {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre um campeonato antes de premiar alunos.'),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => AwardTrophyDialog(
        academyId: widget.academyId,
        template: t,
        events: _events,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conquistas Manuais'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.star_rounded), text: 'Troféus Livres'),
            Tab(icon: Icon(Icons.emoji_events_rounded), text: 'Campeonatos'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _CustomTab(
                      templates: _customTemplates,
                      onNew: _newCustomTemplate,
                      onEdit: _editCustomTemplate,
                      onDelete: _deleteTemplate,
                      onAward: _awardCustomTrophy,
                    ),
                    _ChampionshipTab(
                      templates: _championshipTemplates,
                      events: _events,
                      onNewTemplate: _newChampionshipTemplate,
                      onDeleteTemplate: _deleteTemplate,
                      onAward: _awardChampionshipMedal,
                      onNewEvent: _newEvent,
                      onDeleteEvent: _deleteEvent,
                    ),
                  ],
                ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: AppSpacing.m),
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

// ---------------------------------------------------------------------------
// Aba: Troféus Livres
// ---------------------------------------------------------------------------

class _CustomTab extends StatelessWidget {
  const _CustomTab({
    required this.templates,
    required this.onNew,
    required this.onEdit,
    required this.onDelete,
    required this.onAward,
  });

  final List<TrophyTemplate> templates;
  final VoidCallback onNew;
  final void Function(TrophyTemplate) onEdit;
  final void Function(TrophyTemplate) onDelete;
  final void Function(TrophyTemplate) onAward;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add),
            label: const Text('Novo troféu'),
          ),
          const SizedBox(height: AppSpacing.m),
          if (templates.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  'Nenhum troféu criado ainda.\nCrie o primeiro acima!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            ...templates.map((t) => _TemplateTile(
                  template: t,
                  onEdit: () => onEdit(t),
                  onDelete: () => onDelete(t),
                  onAward: () => onAward(t),
                )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aba: Campeonatos
// ---------------------------------------------------------------------------

class _ChampionshipTab extends StatelessWidget {
  const _ChampionshipTab({
    required this.templates,
    required this.events,
    required this.onNewTemplate,
    required this.onDeleteTemplate,
    required this.onAward,
    required this.onNewEvent,
    required this.onDeleteEvent,
  });

  final List<TrophyTemplate> templates;
  final List<ChampionshipEvent> events;
  final VoidCallback onNewTemplate;
  final void Function(TrophyTemplate) onDeleteTemplate;
  final void Function(TrophyTemplate) onAward;
  final VoidCallback onNewEvent;
  final void Function(ChampionshipEvent) onDeleteEvent;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.m),
      children: [
        // --- Modelos de medalha ---
        Row(
          children: [
            const Expanded(
              child: Text(
                'MODELOS DE MEDALHA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onNewTemplate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        if (templates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nenhum modelo. Ex: "Medalha IBJJF".',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          )
        else
          ...templates.map((t) => _TemplateTile(
                template: t,
                onEdit: null,
                onDelete: () => onDeleteTemplate(t),
                onAward: () => onAward(t),
                awardLabel: 'Premiar aluno',
              )),
        const SizedBox(height: AppSpacing.l),
        // --- Campeonatos ---
        Row(
          children: [
            const Expanded(
              child: Text(
                'CAMPEONATOS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onNewEvent,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nenhum campeonato cadastrado ainda.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          )
        else
          ...events.map((e) => _EventTile(event: e, onDelete: () => onDeleteEvent(e))),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets internos
// ---------------------------------------------------------------------------

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.onEdit,
    required this.onDelete,
    required this.onAward,
    this.awardLabel = 'Premiar aluno',
  });

  final TrophyTemplate template;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAward;
  final String awardLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.military_tech_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (template.description != null &&
                          template.description!.isNotEmpty)
                        Text(
                          template.description!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit?.call();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_rounded),
                          title: Text('Editar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('Remover', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAward,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: Text(awardLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onDelete});

  final ChampionshipEvent event;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFF3E0),
          child: Icon(Icons.emoji_events_rounded, color: Color(0xFFE65100)),
        ),
        title: Text(event.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            event.eventDate,
            if (event.location != null && event.location!.isNotEmpty) event.location,
          ].join(' · '),
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDelete,
          tooltip: 'Remover campeonato',
        ),
      ),
    );
  }
}
