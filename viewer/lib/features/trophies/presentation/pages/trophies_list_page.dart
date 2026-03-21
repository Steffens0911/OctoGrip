import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';
import 'package:viewer/features/trophies/presentation/providers/trophy_providers.dart';
import 'package:viewer/features/trophies/presentation/state/trophy_list_notifier.dart';
import 'package:viewer/features/trophies/presentation/state/trophy_list_state.dart';
import 'package:viewer/features/trophies/presentation/widgets/trophy_list_card.dart';
import 'package:viewer/features/trophies/presentation/widgets/trophy_search_bar.dart';
import 'package:viewer/screens/admin/trophy_form_screen.dart';
import 'package:viewer/services/auth_service.dart';

class TrophiesListPage extends ConsumerStatefulWidget {
  const TrophiesListPage({
    super.key,
    required this.academyId,
    required this.academyName,
  });

  final String academyId;
  final String academyName;

  @override
  ConsumerState<TrophiesListPage> createState() => _TrophiesListPageState();
}

class _TrophiesListPageState extends ConsumerState<TrophiesListPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm([TrophyEntity? entity]) async {
    final saved = await Navigator.push<TrophyEntity?>(
      context,
      MaterialPageRoute<TrophyEntity?>(
        builder: (context) => TrophyFormScreen(
          academyId: widget.academyId,
          trophy: entity,
        ),
      ),
    );
    if (!mounted) return;
    await ref
        .read(trophyListNotifierProvider(widget.academyId).notifier)
        .syncAfterFormClose(saved: saved);
  }

  Future<void> _confirmDelete(TrophyEntity e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir troféu'),
        content: Text(
          'O troféu "${e.name}" será ocultado (exclusão lógica). Continuar?',
        ),
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
        .read(trophyListNotifierProvider(widget.academyId).notifier)
        .deleteOptimistic(e);

    if (!mounted) return;
    final err = ref.read(trophyListNotifierProvider(widget.academyId)).errorMessage;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Troféu removido')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trophyListNotifierProvider(widget.academyId));
    final notifier =
        ref.read(trophyListNotifierProvider(widget.academyId).notifier);
    final canEdit = AuthService().canEditResources();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1A1A2E) : Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Troféus'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: state.mutationInProgress ? null : () => _openForm(),
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
    TrophyListState state,
    TrophyListNotifier notifier,
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
          onRefresh: state.mutationInProgress ? () async {} : notifier.refresh,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.academyName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Troféus desta academia (ouro/prata/bronze por execuções)',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TrophySearchBar(
                          controller: _searchController,
                          onChanged: notifier.onSearchChanged,
                          onClear: notifier.clearSearch,
                        ),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        state.searchQuery.trim().isNotEmpty
                            ? 'Nenhum troféu encontrado.'
                            : 'Nenhum troféu. Toque em + para criar.',
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
                          return TrophyListCard(
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
