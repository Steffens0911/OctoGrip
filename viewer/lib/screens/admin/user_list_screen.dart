import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/user.dart' as models;
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
  List<models.UserModel> _items = [];
  List<Academy> _academies = [];
  String? _filterAcademyId;
  String? _filterGraduation;
  bool _loading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 50;
  String? _error;
  String _searchQuery = '';

  static const List<MapEntry<String, String>> _graduations = [
    MapEntry('white', 'Branca'),
    MapEntry('blue', 'Azul'),
    MapEntry('purple', 'Roxa'),
    MapEntry('brown', 'Marrom'),
    MapEntry('black', 'Preta'),
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<models.UserModel>> _fetchUsers({required int offset}) {
    final isAdmin = AuthService().isAdmin();
    return isAdmin
        ? _api.getUsers(
            offset: offset,
            limit: _pageSize,
            search: _searchQuery.isNotEmpty ? _searchQuery : null,
            academyId: _filterAcademyId,
            graduation: _filterGraduation,
          )
        : _api.getUsers(
            academyId: AuthService().currentUser?.academyId,
            offset: offset,
            limit: _pageSize,
            search: _searchQuery.isNotEmpty ? _searchQuery : null,
            graduation: _filterGraduation,
          );
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _currentPage = 0; _hasMore = true; });
    try {
      final results = await Future.wait([
        _fetchUsers(offset: 0),
        _api.getAcademies(),
      ]);
      final list = results[0] as List<models.UserModel>;
      if (mounted) {
        setState(() {
          _items = list;
          _academies = results[1] as List<Academy>;
          _loading = false;
          _hasMore = list.length >= _pageSize;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = userFacingMessage(e); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextOffset = (_currentPage + 1) * _pageSize;
      final list = await _fetchUsers(offset: nextOffset);
      if (mounted) {
        setState(() {
          _items = [..._items, ...list];
          _currentPage++;
          _hasMore = list.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
      if (mounted) {
        AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
      }
    }
  }

  @override
  void initState() {
    super.initState();
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

  bool get _hasFilters => _searchQuery.isNotEmpty || _filterAcademyId != null || _filterGraduation != null;

  @override
  Widget build(BuildContext context) {
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
              : _items.isEmpty && !_hasFilters
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
                                              _load();
                                            },
                                          )
                                        : null,
                                  ),
                                  onChanged: (v) {
                                    _debounceTimer?.cancel();
                                    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
                                      setState(() => _searchQuery = v.trim());
                                      _load();
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (AuthService().isAdmin())
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: _filterAcademyId,
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
                                        value: _filterGraduation,
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
                                          _load();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                if (_hasFilters)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Mostrando ${_items.length} resultado${_items.length != 1 ? 's' : ''}',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                          ),
                                        ),
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
                            child: _items.isEmpty
                                ? const AppScreenState.empty(message: 'Nenhum usuário encontrado.')
                                : AppListScaffold(
                                    onRefresh: _load,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppTheme.screenPadding(context),
                                      vertical: 12,
                                    ),
                                    children: [
                                      ...List.generate(_items.length, (i) {
                                        final u = _items[i];
                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          child: ListTile(
                                            title: Text(u.email),
                                            subtitle: Text(u.name ?? '—'),
                                            trailing: Row(
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
                                            onTap: () => _openForm(u),
                                          ),
                                        );
                                      }),
                                      if (_isLoadingMore)
                                        const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(child: CircularProgressIndicator()),
                                        ),
                                      if (_hasMore && !_isLoadingMore)
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: FilledButton(
                                            onPressed: _loadMore,
                                            child: const Text('Carregar mais'),
                                          ),
                                        ),
                                    ],
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
