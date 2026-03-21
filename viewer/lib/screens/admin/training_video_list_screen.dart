import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/training_video.dart';
import 'package:viewer/screens/admin/training_video_form_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';

class TrainingVideoListScreen extends StatefulWidget {
  final bool localOnly;

  const TrainingVideoListScreen({super.key, this.localOnly = false});

  @override
  State<TrainingVideoListScreen> createState() =>
      _TrainingVideoListScreenState();
}

class _TrainingVideoListScreenState extends State<TrainingVideoListScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  List<TrainingVideo> _all = [];
  List<TrainingVideo> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    var list = _all;
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((v) =>
              v.title.toLowerCase().contains(q) ||
              v.youtubeUrl.toLowerCase().contains(q))
          .toList();
    }
    setState(() {
      _filtered = list;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final videos = await _api.getTrainingVideosAdmin();
      if (!mounted) return;
      if (widget.localOnly) {
        final currentUser = AuthService().currentUser;
        final academyId = currentUser?.academyId;
        if (academyId != null && academyId.isNotEmpty) {
          _all = videos.where((v) => v.academyId == academyId).toList();
        } else {
          _all = [];
        }
      } else {
        // Admin global: nesta tela mostrar apenas vídeos globais (apoiadores do app).
        final isAdmin = AuthService().isAdmin();
        if (isAdmin) {
          _all = videos
              .where(
                  (v) => v.academyId == null || (v.academyId?.isEmpty ?? true))
              .toList();
        } else {
          _all = videos;
        }
      }
      _applyFilters();
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingMessage(e);
      });
    }
  }

  Future<void> _openForm([TrainingVideo? video]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TrainingVideoFormScreen(video: video),
      ),
    );
    if (changed == true && mounted) {
      _load();
    }
  }

  Future<void> _delete(TrainingVideo video) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir vídeo de treinamento'),
        content: Text('Excluir "${video.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteTrainingVideo(video.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vídeo excluído.')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = AuthService().canEditResources();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vídeos de treinamento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : _all.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum vídeo de treinamento. Toque em + para criar.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondaryOf(context),
                            ),
                      ),
                    )
                  : Column(
                      children: [
                        if (!widget.localOnly && AuthService().isAdmin())
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Card(
                              color: AppTheme.primary.withValues(alpha: 0.06),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 20,
                                      color: AppTheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Para exibir ou ocultar o quadro "Apoiadores do app" na home do aluno: Administração → Academias → toque em uma academia → role até "Visibilidade na tela do aluno".',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppTheme.textSecondaryOf(
                                                  context),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Buscar por título ou link',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        _applyFilters();
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (_) => _applyFilters(),
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            color: AppTheme.primary,
                            child: ListView.builder(
                              padding: EdgeInsets.all(
                                  AppTheme.screenPadding(context)),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) {
                                final v = _filtered[i];
                                final scopeLabel = v.academyId == null
                                    ? 'Global'
                                    : (v.academyName?.isNotEmpty == true
                                        ? 'Academia: ${v.academyName}'
                                        : 'Somente academia');
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(
                                      v.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${v.pointsPerDay} pts/dia · $scopeLabel',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppTheme.textSecondaryOf(
                                                    context),
                                              ),
                                        ),
                                        Text(
                                          v.youtubeUrl,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppTheme.textMutedOf(
                                                    context),
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                    trailing: canEdit
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (!v.isActive)
                                                const Icon(
                                                  Icons.visibility_off,
                                                  size: 18,
                                                  color: Colors.grey,
                                                ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit,
                                                  color: AppTheme.primary,
                                                ),
                                                onPressed: () => _openForm(v),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () => _delete(v),
                                              ),
                                            ],
                                          )
                                        : null,
                                    onTap: () => _openForm(v),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
