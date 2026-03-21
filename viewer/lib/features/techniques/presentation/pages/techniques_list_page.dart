import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/presentation/providers/technique_providers.dart';
import 'package:viewer/features/techniques/presentation/state/technique_list_notifier.dart';
import 'package:viewer/features/techniques/presentation/state/technique_list_state.dart';
import 'package:viewer/features/techniques/presentation/widgets/technique_list_card.dart';
import 'package:viewer/features/techniques/presentation/widgets/technique_quick_create_sheet.dart';
import 'package:viewer/features/techniques/presentation/widgets/technique_search_bar.dart';
import 'package:viewer/models/technique.dart' as legacy;
import 'package:viewer/screens/admin/technique_form_screen.dart';
import 'package:viewer/services/auth_service.dart';

/// Tela principal do módulo de técnicas (Clean Architecture + Riverpod).
class TechniquesListPage extends ConsumerStatefulWidget {
  const TechniquesListPage({super.key, required this.academyId});

  final String academyId;

  @override
  ConsumerState<TechniquesListPage> createState() => _TechniquesListPageState();
}

class _TechniquesListPageState extends ConsumerState<TechniquesListPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showQuickCreate() async {
    await TechniqueQuickCreateSheet.show(
      context,
      academyId: widget.academyId,
      onRequestFullForm: () => _openForm(),
    );
  }

  Future<void> _openForm([TechniqueEntity? entity]) async {
    final legacyModel = entity == null
        ? null
        : legacy.Technique(
            id: entity.id,
            name: entity.name,
            slug: entity.slug,
            description: entity.description,
            videoUrl: entity.videoUrl,
          );
    final saved = await Navigator.push<legacy.Technique?>(
      context,
      MaterialPageRoute<legacy.Technique?>(
        builder: (context) => TechniqueFormScreen(
          academyId: widget.academyId,
          technique: legacyModel,
        ),
      ),
    );
    if (!mounted) return;
    await ref
        .read(techniqueListNotifierProvider(widget.academyId).notifier)
        .syncAfterFormClose(
          saved: saved == null
              ? null
              : TechniqueEntity(
                  id: saved.id,
                  academyId: widget.academyId,
                  name: saved.name,
                  slug: saved.slug,
                  description: saved.description,
                  videoUrl: saved.videoUrl,
                ),
        );
  }

  Future<void> _confirmDelete(TechniqueEntity e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir técnica'),
        content: Text('Excluir "${e.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await ref
        .read(techniqueListNotifierProvider(widget.academyId).notifier)
        .deleteOptimistic(e);

    if (!mounted) return;
    final err = ref.read(techniqueListNotifierProvider(widget.academyId)).errorMessage;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Técnica excluída')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(techniqueListNotifierProvider(widget.academyId));
    final notifier =
        ref.read(techniqueListNotifierProvider(widget.academyId).notifier);
    final canEdit = AuthService().canEditResources();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1A1A2E) : Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Técnicas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Formulário completo',
              icon: const Icon(Icons.article_outlined),
              onPressed: state.mutationInProgress ? null : () => _openForm(),
            ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: state.mutationInProgress ? null : _showQuickCreate,
              backgroundColor: const Color(0xFF67E0A3),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: _buildBody(context, state, notifier, canEdit),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TechniqueListState state,
    TechniqueListNotifier notifier,
    bool canEdit,
  ) {
    if (state.isInitialLoading && state.allItems.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (state.errorMessage != null &&
        state.allItems.isEmpty &&
        !state.isInitialLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => notifier.refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = state.filtered;
    final visible = state.visible;

    return Stack(
      children: [
        RefreshIndicator(
          color: AppTheme.primary,
          onRefresh:
              state.mutationInProgress ? () async {} : notifier.refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent * 0.85) {
                notifier.loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
            if (state.showingStaleCache && state.errorMessage != null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.screenPadding(context),
                  12,
                  AppTheme.screenPadding(context),
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.cloud_off_outlined,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.errorMessage!,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: state.isRefreshing || state.mutationInProgress
                                  ? null
                                  : () => notifier.refresh(),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Tentar novamente'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.screenPadding(context),
                16,
                AppTheme.screenPadding(context),
                8,
              ),
              sliver: SliverToBoxAdapter(
                child: TechniqueSearchBar(
                  controller: _searchController,
                  onChanged: notifier.onSearchChanged,
                  onClear: notifier.clearSearch,
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    state.searchQuery.trim().isNotEmpty
                        ? 'Nenhuma técnica encontrada.'
                        : 'Nenhuma técnica. Toque em + para criar (rápido).',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.screenPadding(context),
                  8,
                  AppTheme.screenPadding(context),
                  88,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final t = visible[i];
                      return TechniqueListCard(
                        entity: t,
                        canEdit: canEdit,
                        onEdit: () => _openForm(t),
                        onDelete: () => _confirmDelete(t),
                      );
                    },
                    childCount: visible.length,
                  ),
                ),
              ),
            ],
          ],
            ),
          ),
        ),
        if (state.mutationInProgress)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
