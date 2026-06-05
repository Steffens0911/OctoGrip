import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/features/photos/presentation/pages/student_photos_feed_screen.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

const _kPageSize = 20;

class StudentSearchPhotosPage extends StatefulWidget {
  const StudentSearchPhotosPage({super.key, required this.academyId});

  final String academyId;

  @override
  State<StudentSearchPhotosPage> createState() =>
      _StudentSearchPhotosPageState();
}

class _StudentSearchPhotosPageState extends State<StudentSearchPhotosPage> {
  final _api = ApiService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  List<UserModel> _results = [];
  bool _loadingInitial = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPage(query: '', reset: true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.85) {
      _loadPage(query: _currentQuery, reset: false);
    }
  }

  Future<void> _loadPage({required String query, required bool reset}) async {
    if (reset) {
      setState(() {
        _loadingInitial = true;
        _error = null;
        _results = [];
        _hasMore = true;
        _currentQuery = query;
      });
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final offset = reset ? 0 : _results.length;
      final users = await _api.getUsers(
        academyId: widget.academyId,
        // string não-nula força path autenticado sem bypassar impersonação
        search: query.isEmpty ? '' : query,
        limit: _kPageSize,
        offset: offset,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _results = users;
        } else {
          _results = [..._results, ...users];
        }
        _hasMore = users.length == _kPageSize;
        _loadingInitial = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = reset ? 'Não foi possível carregar os alunos.' : null;
        _loadingInitial = false;
        _loadingMore = false;
      });
    }
  }

  void _onQueryChanged(String raw) {
    setState(() {}); // atualiza ícone de limpar
    final query = raw.trim();
    if (query == _currentQuery) return;
    _loadPage(query: query, reset: true);
  }

  static const Map<String, String> _beltLabels = {
    'white': 'Branca',
    'blue': 'Azul',
    'purple': 'Roxa',
    'brown': 'Marrom',
    'black': 'Preta',
  };

  static const Map<String, Color> _beltColors = {
    'white': Color(0xFFEEEEEE),
    'blue': Color(0xFF1565C0),
    'purple': Color(0xFF6A1B9A),
    'brown': Color(0xFF4E342E),
    'black': Color(0xFF212121),
  };

  void _openStudentFeed(UserModel user) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => StudentPhotosFeedPage(
          academyId: widget.academyId,
          studentId: user.id,
          studentName: user.name ?? 'Aluno',
        ),
      ),
    );
  }

  Widget _buildItem(UserModel user) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = user.name ?? 'Aluno';
    final graduation = (user.graduation ?? '').toLowerCase();
    final beltLabel = _beltLabels[graduation] ?? graduation;
    final beltColor = _beltColors[graduation] ?? Colors.grey;
    final avatarUrl = user.avatarUrl ?? '';
    final baseUrl = _api.baseUrl;
    final fullAvatarUrl =
        avatarUrl.startsWith('/') ? '$baseUrl$avatarUrl' : avatarUrl;

    return ListTile(
      onTap: () => _openStudentFeed(user),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: cs.primaryContainer,
        backgroundImage:
            fullAvatarUrl.isNotEmpty ? NetworkImage(fullAvatarUrl) : null,
        child: fullAvatarUrl.isEmpty
            ? Text(
                name[0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer,
                ),
              )
            : null,
      ),
      title: Text(name,
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: graduation.isNotEmpty
          ? Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: beltColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: cs.outline.withValues(alpha: 0.4)),
                  ),
                ),
                Text(
                  'Faixa $beltLabel',
                  style: tt.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            )
          : null,
      trailing:
          Icon(Icons.chevron_right, color: AppTheme.textSecondaryOf(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppStandardAppBar(title: 'Buscar aluno'),
      body: Column(
        children: [
          // Campo de busca
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Nome do aluno…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onQueryChanged,
              onSubmitted: (v) => _loadPage(query: v.trim(), reset: true),
            ),
          ),

          // Corpo
          Expanded(
            child: _loadingInitial
                ? Center(child: CircularProgressIndicator(color: cs.primary))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!,
                                style: TextStyle(color: cs.error)),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => _loadPage(
                                  query: _currentQuery, reset: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum aluno encontrado.',
                              style: tt.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondaryOf(context)),
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 32),
                            itemCount:
                                _results.length + (_hasMore ? 1 : 0),
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: cs.outline.withValues(alpha: 0.15),
                            ),
                            itemBuilder: (context, i) {
                              if (i == _results.length) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: _loadingMore
                                        ? CircularProgressIndicator(
                                            color: cs.primary)
                                        : const SizedBox.shrink(),
                                  ),
                                );
                              }
                              return _buildItem(_results[i]);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
