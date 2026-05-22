import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/user.dart' as models;
import 'package:viewer/models/user_academy_stats.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/screens/admin/user_form_screen.dart';
import 'package:viewer/features/trophy_shelf/presentation/trophy_shelf_page.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_list_scaffold.dart';
import 'package:viewer/widgets/app_screen_state.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _importing = false;

  List<models.UserModel> _allItems = [];
  List<Academy> _academies = [];
  String? _filterAcademyId;
  String? _filterGraduation;
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  Map<String, UserAcademyStats> _statsMap = {};
  late DateTime _fromDate;
  late DateTime _toDate;

  String? _sortBy;
  bool _sortAscending = false;

  static const List<MapEntry<String, String>> _graduations = [
    MapEntry('white', 'Branca'),
    MapEntry('blue', 'Azul'),
    MapEntry('purple', 'Roxa'),
    MapEntry('brown', 'Marrom'),
    MapEntry('black', 'Preta'),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = now.subtract(const Duration(days: 30));
    _toDate = now;
    _load();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String? _academyIdForQuery() {
    if (AuthService().isAdmin()) return _filterAcademyId;
    return AuthService().currentUser?.academyId;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final isAdmin = AuthService().isAdmin();
      final academyId = _academyIdForQuery();

      // Academias só interessam ao admin
      final academiesFuture = isAdmin ? _api.getAcademies() : Future.value(<Academy>[]);

      // Com academia definida: carrega todos os alunos de uma vez (sem paginação)
      // para que busca, filtros e ordenação funcionem sobre o conjunto completo.
      final Future<List<models.UserModel>> usersFuture;
      final Future<Map<String, UserAcademyStats>> statsFuture;

      if (academyId != null) {
        usersFuture = _api.getUsersAll(academyId: academyId);
        statsFuture = _api.getAcademyStudentStats(
          fromDate: _fromDate,
          toDate: _toDate,
          academyId: academyId,
        );
      } else if (isAdmin) {
        // Admin sem academia selecionada: carrega primeira página sem stats
        usersFuture = _api.getUsers(offset: 0, limit: 50);
        statsFuture = Future.value({});
      } else {
        usersFuture = Future.value([]);
        statsFuture = Future.value({});
      }

      final results = await Future.wait([academiesFuture, usersFuture, statsFuture]);
      if (mounted) {
        setState(() {
          _academies = results[0] as List<Academy>;
          _allItems = results[1] as List<models.UserModel>;
          _statsMap = results[2] as Map<String, UserAcademyStats>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = userFacingMessage(e); _loading = false; });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      helpText: 'Selecione o período',
      saveText: 'Confirmar',
      cancelText: 'Cancelar',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _fromDate = picked.start;
      _toDate = picked.end;
    });
    _load();
  }

  Future<void> _openForm([models.UserModel? user]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => UserFormScreen(user: user)));
    if (mounted) _load();
  }

  Future<void> _bulkImportStudents() async {
    if (_importing) return;
    final isAdmin = AuthService().isAdmin();
    final academyId = isAdmin ? _filterAcademyId : AuthService().currentUser?.academyId;
    if (academyId == null || academyId.isEmpty) {
      AppFeedback.show(
        context,
        message: isAdmin
            ? 'Selecione uma academia no filtro para importar alunos.'
            : 'Seu usuário não está vinculado a uma academia.',
        type: AppFeedbackType.error,
      );
      return;
    }
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (!mounted) return;
    if (pick == null || pick.files.isEmpty) return;
    final f = pick.files.single;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) {
      AppFeedback.show(context, message: 'Não foi possível ler o arquivo. Tente novamente.', type: AppFeedbackType.error);
      return;
    }
    setState(() => _importing = true);
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            content: SizedBox(
              height: 64,
              child: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Expanded(child: Text('Importando alunos...'))]),
            ),
          ),
        );
      }
      final result = await _api.bulkImportStudentsXlsx(academyId: academyId, bytes: bytes, filename: f.name);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final summary = (result['summary'] as Map?) ?? const {};
      final created = summary['created'] ?? 0;
      final skipped = summary['skipped'] ?? 0;
      final failed = summary['failed'] ?? 0;
      final results = (result['results'] as List?) ?? const [];
      final failedLines = results.where((e) => e is Map && e['ok'] == false).take(10).toList();
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Importação concluída'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Criados: $created'),
                  Text('Pulados: $skipped'),
                  Text('Com erro: $failed'),
                  if (failedLines.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Primeiros erros:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...failedLines.map((e) {
                      final m = e as Map;
                      final row = m['row_number'] ?? '?';
                      final errs = (m['errors'] as List?) ?? const [];
                      final first = errs.isNotEmpty && errs.first is Map ? (errs.first as Map)['message'] : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('Linha $row: ${first ?? 'Erro na linha'}'),
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
      if (mounted) _load();
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _delete(models.UserModel u) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Esta ação é irreversível sem backup SQL. Para confirmar, digite o e-mail do utilizador:'),
            const SizedBox(height: 8),
            Text(u.email, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'E-mail de confirmação', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().toLowerCase() == u.email.trim().toLowerCase()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (ok != true) return;
    try {
      await _api.deleteUser(u.id, confirmEmail: u.email);
      if (mounted) _load();
      if (mounted) AppFeedback.show(context, message: 'Usuário excluído', type: AppFeedbackType.success);
    } catch (e) {
      if (mounted) AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  void _tapSort(String key) {
    setState(() {
      if (_sortBy == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = key;
        _sortAscending = key == 'name';
      }
    });
  }

  // Filtragem client-side sobre o conjunto completo de alunos
  List<models.UserModel> get _filteredItems {
    var list = _allItems;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) =>
        u.email.toLowerCase().contains(q) ||
        (u.name?.toLowerCase().contains(q) ?? false),
      ).toList();
    }
    if (_filterGraduation != null) {
      list = list.where((u) => u.graduation == _filterGraduation).toList();
    }
    return list;
  }

  List<models.UserModel> get _sortedItems {
    if (_sortBy == null) return _filteredItems;
    final sorted = List<models.UserModel>.from(_filteredItems);
    sorted.sort((a, b) {
      final sa = _statsMap[a.id];
      final sb = _statsMap[b.id];
      int cmp;
      switch (_sortBy) {
        case 'name':
          cmp = (a.name ?? a.email).toLowerCase().compareTo((b.name ?? b.email).toLowerCase());
        case 'videos':
          cmp = (sa?.videosInPeriod ?? 0).compareTo(sb?.videosInPeriod ?? 0);
        case 'positions':
          cmp = (sa?.positionsInPeriod ?? 0).compareTo(sb?.positionsInPeriod ?? 0);
        case 'workouts':
          cmp = (sa?.workoutsInPeriod ?? 0).compareTo(sb?.workoutsInPeriod ?? 0);
        case 'trophies':
          cmp = (sa?.trophiesCount ?? 0).compareTo(sb?.trophiesCount ?? 0);
        case 'inactive':
          cmp = (sa?.daysSinceLastWorkout ?? 0).compareTo(sb?.daysSinceLastWorkout ?? 0);
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  bool get _hasFilters => _searchQuery.isNotEmpty || _filterAcademyId != null || _filterGraduation != null;

  String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final displayItems = _sortedItems;

    return Scaffold(
      appBar: AppStandardAppBar(
        title: 'Usuários',
        actions: [
          if (AuthService().canEditResources())
            IconButton(
              tooltip: 'Importar alunos (Excel)',
              onPressed: _importing ? null : _bulkImportStudents,
              icon: const Icon(Icons.upload_file),
            ),
        ],
      ),
      body: _loading
          ? const AppScreenState.loading()
          : _error != null
              ? AppScreenState.error(message: _error!, onRetry: _load)
              : _allItems.isEmpty && !_hasFilters
                  ? const AppScreenState.empty(message: 'Nenhum usuário. Toque em + para criar.')
                  : AppScreenState.content(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Buscar por nome ou email',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                          )
                                        : null,
                                  ),
                                  onChanged: (v) {
                                    _debounceTimer?.cancel();
                                    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
                                      setState(() => _searchQuery = v.trim());
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (AuthService().isAdmin())
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _filterAcademyId,
                                          decoration: const InputDecoration(
                                            labelText: 'Academia',
                                            hintText: 'Todas',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                            isDense: true,
                                          ),
                                          items: [
                                            const DropdownMenuItem(value: null, child: Text('Todas')),
                                            ..._academies.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                                          ],
                                          onChanged: (v) {
                                            setState(() => _filterAcademyId = v);
                                            _load();
                                          },
                                        ),
                                      ),
                                    if (AuthService().isAdmin()) const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _filterGraduation,
                                        decoration: const InputDecoration(
                                          labelText: 'Graduação',
                                          hintText: 'Todas',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                          isDense: true,
                                        ),
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('Todas')),
                                          ..._graduations.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                                        ],
                                        onChanged: (v) {
                                          setState(() => _filterGraduation = v);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Seletor de período
                                InkWell(
                                  onTap: _pickDateRange,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 16, color: AppTheme.textSecondaryOf(context)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Período: ${_fmtDate(_fromDate)} – ${_fmtDate(_toDate)}',
                                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.edit_calendar_outlined, size: 16, color: AppTheme.textSecondaryOf(context)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Chips de ordenação
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      Text('Ordenar:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                                      const SizedBox(width: 8),
                                      ...[
                                        ('name', 'Nome', Icons.sort_by_alpha),
                                        ('videos', 'Vídeos', Icons.play_circle_outline),
                                        ('positions', 'Posições', Icons.sports_martial_arts),
                                        ('workouts', 'Presenças', Icons.fitness_center),
                                        ('trophies', 'Troféus', Icons.emoji_events_outlined),
                                        ('inactive', 'Inativos', Icons.warning_amber_rounded),
                                      ].map((entry) {
                                        final key = entry.$1;
                                        final label = entry.$2;
                                        final icon = entry.$3;
                                        final active = _sortBy == key;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: FilterChip(
                                            label: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(icon, size: 13),
                                                const SizedBox(width: 4),
                                                Text(label, style: const TextStyle(fontSize: 12)),
                                                if (active) ...[
                                                  const SizedBox(width: 2),
                                                  Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 11),
                                                ],
                                              ],
                                            ),
                                            selected: active,
                                            onSelected: (_) => _tapSort(key),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${displayItems.length} de ${_allItems.length} aluno${_allItems.length != 1 ? 's' : ''}',
                                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                                        ),
                                      ),
                                      if (_hasFilters)
                                        TextButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchQuery = '';
                                              _filterAcademyId = null;
                                              _filterGraduation = null;
                                            });
                                            _load();
                                          },
                                          child: const Text('Limpar filtros'),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: displayItems.isEmpty
                                ? const AppScreenState.empty(message: 'Nenhum usuário encontrado.')
                                : AppListScaffold(
                                    onRefresh: _load,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppTheme.screenPadding(context),
                                      vertical: 12,
                                    ),
                                    children: List.generate(displayItems.length, (i) {
                                      final u = displayItems[i];
                                      final stats = _statsMap[u.id];
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: InkWell(
                                          onTap: () => _openForm(u),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  u.email,
                                                                  style: Theme.of(context).textTheme.bodyMedium,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                              if (u.accountFrozen)
                                                                const Tooltip(
                                                                  message: 'Conta congelada: o aluno não consegue acessar o app',
                                                                  child: Padding(
                                                                    padding: EdgeInsets.only(left: 4),
                                                                    child: Icon(Icons.lock_outline, size: 14, color: Colors.orange),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                          if (u.name != null)
                                                            Text(
                                                              u.name!,
                                                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(Icons.emoji_events_outlined),
                                                          tooltip: 'Ver galeria de troféus',
                                                          onPressed: () => Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) => TrophyShelfPage(userId: u.id, userName: u.name ?? u.email),
                                                            ),
                                                          ),
                                                        ),
                                                        if (AuthService().canEditResources()) ...[
                                                          IconButton(icon: const Icon(Icons.edit, color: AppTheme.primary), onPressed: () => _openForm(u)),
                                                          IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), onPressed: () => _delete(u)),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                if (stats != null) ...[
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: [
                                                      _StatChip(
                                                        icon: Icons.play_circle_outline,
                                                        value: stats.videosInPeriod,
                                                        tooltip: 'Vídeos de treinamento assistidos no período selecionado',
                                                      ),
                                                      _StatChip(
                                                        icon: Icons.sports_martial_arts,
                                                        value: stats.positionsInPeriod,
                                                        tooltip: 'Posições aplicadas e confirmadas pelo adversário no período',
                                                      ),
                                                      _StatChip(
                                                        icon: Icons.fitness_center,
                                                        value: stats.workoutsInPeriod,
                                                        tooltip: 'Presenças registradas em chamadas de aula no período',
                                                      ),
                                                      _StatChip(
                                                        icon: Icons.emoji_events_outlined,
                                                        value: stats.trophiesCount,
                                                        tooltip: 'Total de troféus e medalhas conquistados pelo aluno',
                                                      ),
                                                      if (stats.daysSinceLastWorkout != null && stats.daysSinceLastWorkout! > 14)
                                                        _InactivityChip(days: stats.daysSinceLastWorkout!),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                          ),
                        ],
                      ),
                    ),
      floatingActionButton: AuthService().canEditResources()
          ? FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add))
          : null,
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final String tooltip;

  const _StatChip({required this.icon, required this.value, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = cs.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Text(value.toString(), style: TextStyle(fontSize: 12, color: fg)),
          ],
        ),
      ),
    );
  }
}

class _InactivityChip extends StatelessWidget {
  final int days;

  const _InactivityChip({required this.days});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sem aparecer na chamada de aula há $days dias — aluno pode precisar de atenção',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 13, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              '${days}d sem treinar',
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
