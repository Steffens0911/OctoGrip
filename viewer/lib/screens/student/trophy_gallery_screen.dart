import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/features/trophy_shelf/presentation/trophy_shelf_page.dart';
import 'package:viewer/models/manual_trophy.dart';
import 'package:viewer/models/trophy.dart';
import 'package:viewer/services/api_service.dart' show ApiException, ApiService;
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/widgets/execution_confirm_sheet.dart';
import 'package:viewer/widgets/opponent_picker_sheet.dart';
import 'package:viewer/widgets/youtube_player_embed.dart';

/// Galeria de troféus e medalhas do usuário: premiações da academia com tier conquistado (ouro/prata/bronze) ou "A conquistar".
class TrophyGalleryScreen extends StatefulWidget {
  final String userId;
  final String? userName;

  const TrophyGalleryScreen({super.key, required this.userId, this.userName});

  @override
  State<TrophyGalleryScreen> createState() => _TrophyGalleryScreenState();
}

class _TrophyGalleryScreenState extends State<TrophyGalleryScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  List<TrophyWithEarned> _allItems = [];
  List<TrophyWithEarned> _filteredItems = [];
  String?
      _filterTier; // null=Todos, 'to_conquer'=A conquistar, 'bronze','silver','gold'
  String? _filterAwardKind; // null=Todos, 'medal', 'trophy'
  bool _loading = true;
  String? _error;
  bool _galleryVisible = true;

  bool get _isOwnGallery => AuthService().currentUser?.id == widget.userId;

  @override
  void initState() {
    super.initState();
    _galleryVisible = AuthService().currentUser?.galleryVisible ?? true;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    var filtered = _allItems;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((t) {
        final name = t.name.toLowerCase();
        final techniqueName = (t.techniqueName ?? '').toLowerCase();
        final note = (t.awardNote ?? '').toLowerCase();
        final event = (t.championshipEventName ?? '').toLowerCase();
        return name.contains(query) || techniqueName.contains(query) ||
            note.contains(query) || event.contains(query);
      }).toList();
    }
    if (_filterTier != null) {
      if (_filterTier == 'to_conquer') {
        filtered = filtered.where((t) => t.earnedTier == null).toList();
      } else {
        filtered = filtered.where((t) => t.earnedTier == _filterTier).toList();
      }
    }
    if (_filterAwardKind != null) {
      filtered =
          filtered.where((t) => t.awardKind == _filterAwardKind).toList();
    }
    setState(() => _filteredItems = filtered);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trophiesFuture = _api.getTrophiesForUser(widget.userId);
      final manualFuture = _api.getUserManualTrophyAwards(widget.userId);
      final list = await trophiesFuture;
      List<TrophyWithEarned> manualItems = [];
      try {
        final raw = await manualFuture;
        final manual = UserTrophyAwardsResponse.fromJson(raw);
        final allAwards = [...manual.championshipAwards, ...manual.customAwards];
        manualItems = allAwards
            .map((a) => TrophyWithEarned.fromManualAward(a))
            .toList();
      } catch (_) {
        // Silencia erro das conquistas manuais para não bloquear a galeria
      }
      if (mounted) {
        setState(() {
          // Manuais primeiro (mais recentes no topo), depois os regulares
          _allItems = [...manualItems, ...list];
          _loading = false;
        });
      }
      _applyFilters();
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException && e.statusCode == 403
            ? 'Esta galeria está privada.'
            : userFacingMessage(e);
        setState(() {
          _error = msg;
          _loading = false;
        });
      }
    }
  }

  Future<void> _onGalleryVisibleChanged(bool value) async {
    setState(() => _galleryVisible = value);
    try {
      await _api.patchMeGalleryVisible(value);
      await AuthService().refreshMe();
    } catch (e) {
      if (mounted) {
        setState(() => _galleryVisible = !value);
        AppFeedback.show(
          context,
          message: userFacingMessage(e),
          type: AppFeedbackType.error,
        );
      }
    }
  }

  static String _formatSingleDate(String iso) {
    try {
      final d = DateTime.tryParse(iso);
      if (d == null) return iso;
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  static String _formatDateRange(String startIso, String endIso) {
    try {
      final start = DateTime.tryParse(startIso);
      final end = DateTime.tryParse(endIso);
      if (start == null || end == null) return '$startIso – $endIso';
      return '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year} – '
          '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}';
    } catch (_) {
      return '$startIso – $endIso';
    }
  }

  static Color _tierColor(String? tier) {
    switch (tier) {
      case 'gold':
        return const Color(0xFFD97706);
      case 'silver':
        return const Color(0xFF6B7280);
      case 'bronze':
        return const Color(0xFF92400E);
      default:
        return AppTheme.textMuted;
    }
  }

  static IconData _tierIcon(String? tier) {
    switch (tier) {
      case 'gold':
        return Icons.emoji_events;
      case 'silver':
        return Icons.emoji_events;
      case 'bronze':
        return Icons.emoji_events;
      default:
        return Icons.workspace_premium_outlined;
    }
  }

  Future<String?> _showUsageTypeDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PointerInterceptor(
        child: AlertDialog(
          content: const Text(
            'A execução foi premeditada focando no troféu/medalha ou posição do dia?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'planned'),
              child: const Text('Sim'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'natural'),
              child: const Text('Não, aconteceu naturalmente'),
            ),
          ],
        ),
      ),
    );
  }

  Future<UserModel?> _showOpponentDialogWithUser(String academyId) {
    return OpponentPickerSheet.showWithUser(
      context,
      academyId: academyId,
      currentUserId: widget.userId,
      allowSkip: false,
    );
  }

  Future<void> _indicateOpponent(TrophyWithEarned t) async {
    final academyId = t.academyId;
    if (academyId == null || academyId.isEmpty) {
      if (mounted) {
        AppFeedback.show(
          context,
          message: 'Academia não definida para este troféu.',
          type: AppFeedbackType.warning,
        );
      }
      return;
    }
    final usageTypeUi = await _showUsageTypeDialog();
    if (usageTypeUi == null || !mounted) return;
    final usageType = usageTypeUi == 'planned'
        ? 'after_training'
        : usageTypeUi == 'natural'
            ? 'before_training'
            : usageTypeUi;
    final opponent = await _showOpponentDialogWithUser(academyId);
    if (opponent == null || !mounted) return;
    final confirmed = await ExecutionConfirmSheet.show(
      context,
      techniqueName: t.techniqueName ?? t.name,
      opponentName: opponent.name ?? opponent.email,
    );
    if (!confirmed || !mounted) return;
    try {
      final res = await _api.postExecution(
        techniqueId: t.techniqueId,
        academyId: academyId,
        opponentId: opponent.id,
        usageType: usageType,
      );
      if (!mounted) return;
      final message =
          res['message'] as String? ?? 'Aguardando confirmação do adversário.';
      AppFeedback.show(
        context,
        message: message,
        type: AppFeedbackType.info,
      );
      _load();
    } catch (e) {
      if (mounted) {
        AppFeedback.show(
          context,
          message: userFacingMessage(e),
          type: AppFeedbackType.error,
        );
      }
    }
  }

  void _showTechniqueVideo(BuildContext context, TrophyWithEarned t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              t.techniqueName ?? t.name,
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              t.name,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(ctx),
                  ),
            ),
            const SizedBox(height: 16),
            YoutubePlayerEmbed(
              videoUrl: t.techniqueVideoUrl!,
              reelsMode: false,
            ),
          ],
        ),
      ),
    );
  }

  /// Linhas de progresso por tier (só para tiers ainda não conquistados).
  List<Widget> _progressLines(BuildContext context, TrophyWithEarned t) {
    final style =
        TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context));
    final lines = <Widget>[];
    final target = t.targetCount;
    final cap = t.maxCountPerOpponent;
    if (cap != null) {
      lines.add(Text(
        'Limite: no máximo $cap execução(ões) contáveis por adversário no período.',
        style: style,
      ));
    }
    final hasGold = t.earnedTier == 'gold';
    final hasSilver = t.earnedTier == 'silver' || hasGold;
    final hasBronze = t.earnedTier == 'bronze' || hasSilver;
    if (hasGold) {
      lines.add(Text('Conquistado: ouro',
          style: style.copyWith(
              fontWeight: FontWeight.w600, color: _tierColor('gold'))));
      return lines;
    }
    // Contagens acumulativas: bronze inclui azuis e roxos+; prata inclui roxos+
    final bronzeTotal = t.bronzeCount + t.silverCount + t.goldCount;
    final silverTotal = t.silverCount + t.goldCount;
    final goldTotal   = t.goldCount;
    if (!hasBronze) {
      final missing = target - bronzeTotal;
      if (missing > 0) {
        final bronzeHint = cap != null
            ? '$bronzeTotal no bronze (qualquer faixa). Faltam $missing para o troféu bronze.'
            : '$bronzeTotal adversários contabilizados. Faltam $missing para o troféu bronze.';
        lines.add(Text(bronzeHint, style: style));
      }
    }
    if (!hasSilver) {
      final missing = target - silverTotal;
      if (missing > 0) {
        lines.add(Text(
          '$silverTotal azuis ou superior contabilizados. Faltam $missing para o troféu prata.',
          style: style,
        ));
      }
    }
    if (!hasGold) {
      final missing = target - goldTotal;
      if (missing > 0) {
        lines.add(Text(
          '$goldTotal em roxa/marrom/preta. Faltam $missing para o troféu ouro.',
          style: style,
        ));
      }
    }
    return lines;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppStandardAppBar(
        title: 'Galeria de troféus e medalhas',
        subtitle:
            (widget.userName != null && widget.userName!.isNotEmpty)
                ? widget.userName
                : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.view_agenda_outlined),
            tooltip: 'Ver como estante',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => TrophyShelfPage(
                  userId: widget.userId,
                  userName: widget.userName,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _error == 'Esta galeria está privada.'
                                ? AppTheme.textSecondaryOf(context)
                                : Colors.red.shade700,
                          ),
                        ),
                        if (_error != 'Esta galeria está privada') ...[
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : _allItems.isEmpty
                  ? Center(
                      child: Text(
                        _isOwnGallery
                            ? 'Nenhum troféu cadastrado na sua academia.'
                            : 'Nenhuma premiação conquistada.',
                        style: const TextStyle(color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (_isOwnGallery)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Galeria visível para outros',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textSecondaryOf(
                                                context),
                                          ),
                                        ),
                                      ),
                                      Switch(
                                        value: _galleryVisible,
                                        onChanged: _onGalleryVisibleChanged,
                                      ),
                                    ],
                                  ),
                                ),
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Buscar por nome ou técnica',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            _applyFilters();
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (_) => _applyFilters(),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilterChip(
                                    label: const Text('Todos'),
                                    selected: _filterAwardKind == null,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _filterAwardKind = null);
                                        _applyFilters();
                                      }
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('Medalhas'),
                                    selected: _filterAwardKind == 'medal',
                                    onSelected: (selected) {
                                      setState(() => _filterAwardKind =
                                          selected ? 'medal' : null);
                                      _applyFilters();
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('Troféus'),
                                    selected: _filterAwardKind == 'trophy',
                                    onSelected: (selected) {
                                      setState(() => _filterAwardKind =
                                          selected ? 'trophy' : null);
                                      _applyFilters();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilterChip(
                                    label: const Text('Todos os tiers'),
                                    selected: _filterTier == null,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _filterTier = null);
                                        _applyFilters();
                                      }
                                    },
                                  ),
                                  if (_isOwnGallery)
                                    FilterChip(
                                      label: const Text('A conquistar'),
                                      selected: _filterTier == 'to_conquer',
                                      onSelected: (selected) {
                                        setState(() => _filterTier =
                                            selected ? 'to_conquer' : null);
                                        _applyFilters();
                                      },
                                    ),
                                  FilterChip(
                                    label: const Text('Bronze'),
                                    selected: _filterTier == 'bronze',
                                    onSelected: (selected) {
                                      setState(() => _filterTier =
                                          selected ? 'bronze' : null);
                                      _applyFilters();
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('Prata'),
                                    selected: _filterTier == 'silver',
                                    onSelected: (selected) {
                                      setState(() => _filterTier =
                                          selected ? 'silver' : null);
                                      _applyFilters();
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('Ouro'),
                                    selected: _filterTier == 'gold',
                                    onSelected: (selected) {
                                      setState(() => _filterTier =
                                          selected ? 'gold' : null);
                                      _applyFilters();
                                    },
                                  ),
                                ],
                              ),
                              if (_searchController.text.isNotEmpty ||
                                  _filterTier != null ||
                                  _filterAwardKind != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Mostrando ${_filteredItems.length} de ${_allItems.length} premiações',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _filterTier = null;
                                            _filterAwardKind = null;
                                          });
                                          _applyFilters();
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
                          child: RefreshIndicator(
                            onRefresh: _load,
                            child: _filteredItems.isEmpty
                                ? Center(
                                    child: Text(
                                      _searchController.text.isNotEmpty ||
                                              _filterTier != null ||
                                              _filterAwardKind != null
                                          ? 'Nenhuma premiação encontrada.'
                                          : 'Nenhuma premiação cadastrada na sua academia.',
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredItems.length,
                                    itemBuilder: (context, i) {
                                      final t = _filteredItems[i];
                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      color: (t.unlocked
                                                              ? _tierColor(
                                                                  t.earnedTier)
                                                              : Colors.grey)
                                                          .withValues(
                                                              alpha: 0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Icon(
                                                      t.unlocked
                                                          ? _tierIcon(
                                                              t.earnedTier)
                                                          : Icons.lock_outline,
                                                      color: t.unlocked
                                                          ? _tierColor(
                                                              t.earnedTier)
                                                          : Colors.grey,
                                                      size: 28,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                t.name,
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: AppTheme
                                                                      .textPrimaryOf(
                                                                          context),
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: t.isTrophy
                                                                    ? Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .primaryContainer
                                                                    : Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .surfaceContainerHighest,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                              child: Text(
                                                                t.awardKindLabel,
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: t.isTrophy
                                                                      ? Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onPrimaryContainer
                                                                      : Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        if (!t.isManualAward &&
                                                            t.techniqueName !=
                                                                null &&
                                                            t.techniqueName!
                                                                .isNotEmpty)
                                                          Text(
                                                            t.techniqueName!,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: AppTheme
                                                                  .textSecondaryOf(
                                                                      context),
                                                            ),
                                                          ),
                                                        if (t.isManualAward) ...[
                                                          if (t.championshipEventName != null)
                                                            Text(
                                                              t.championshipEventName!,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: AppTheme.textSecondaryOf(context),
                                                              ),
                                                            ),
                                                          if (t.awardNote != null && t.awardNote!.isNotEmpty)
                                                            Text(
                                                              t.awardNote!,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: AppTheme.textSecondaryOf(context),
                                                              ),
                                                            ),
                                                          Text(
                                                            'Concedido em ${_formatSingleDate(t.startDate)}',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: AppTheme.textMutedOf(context),
                                                            ),
                                                          ),
                                                        ] else
                                                        Text(
                                                          '${_formatDateRange(t.startDate, t.endDate)} · Meta: ${t.targetCount} execuções',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: AppTheme
                                                                .textMutedOf(
                                                                    context),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: (t.unlocked
                                                              ? _tierColor(
                                                                  t.earnedTier)
                                                              : Colors.grey)
                                                          .withValues(
                                                              alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      t.unlocked
                                                          ? t.tierLabel
                                                          : 'Trancado',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: t.unlocked
                                                            ? _tierColor(
                                                                t.earnedTier)
                                                            : Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (!t.unlocked) ...[
                                                const SizedBox(height: 10),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 4,
                                                  children: [
                                                    if (t.minRewardLevelToUnlock >
                                                        0)
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .lock_outline,
                                                              size: 18,
                                                              color: AppTheme
                                                                  .textSecondaryOf(
                                                                      context)),
                                                          const SizedBox(
                                                              width: 6),
                                                          Text(
                                                            'Alcance o nível ${t.minRewardLevelToUnlock} para desbloquear',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: AppTheme
                                                                  .textSecondaryOf(
                                                                      context),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    if (t.minGraduationToUnlock !=
                                                            null &&
                                                        t.minGraduationToUnlock!
                                                            .isNotEmpty)
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .shield_outlined,
                                                              size: 18,
                                                              color: AppTheme
                                                                  .textSecondaryOf(
                                                                      context)),
                                                          const SizedBox(
                                                              width: 6),
                                                          Text(
                                                            'Requer faixa mínima: ${TrophyWithEarned.graduationLabel(t.minGraduationToUnlock) ?? t.minGraduationToUnlock}',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: AppTheme
                                                                  .textSecondaryOf(
                                                                      context),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              ] else if (!t.isManualAward)
                                                ...() {
                                                  final progressLines =
                                                      _progressLines(
                                                          context, t);
                                                  if (progressLines.isEmpty) {
                                                    return <Widget>[];
                                                  }
                                                  return [
                                                    const SizedBox(height: 10),
                                                    ...progressLines
                                                        .map((w) => Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      bottom:
                                                                          4),
                                                              child: w,
                                                            )),
                                                  ];
                                                }(),
                                              if (t.techniqueVideoUrl != null &&
                                                  t.techniqueVideoUrl!.isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: OutlinedButton.icon(
                                                    icon: const Icon(
                                                        Icons.play_circle_outline_rounded,
                                                        size: 18),
                                                    label: const Text('Ver vídeo da técnica'),
                                                    onPressed: () => _showTechniqueVideo(context, t),
                                                  ),
                                                ),
                                              ],
                                              if (!t.isManualAward &&
                                                  _isOwnGallery &&
                                                  t.unlocked &&
                                                  t.academyId != null &&
                                                  t.academyId!.isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: OutlinedButton.icon(
                                                    icon: const Icon(
                                                        Icons.person_add,
                                                        size: 18),
                                                    label: const Text(
                                                        'Indicar adversário'),
                                                    onPressed: () =>
                                                        _indicateOpponent(t),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

