import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/features/trophy_shelf/presentation/trophy_shelf_page.dart';
import 'package:viewer/models/trophy.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/services/api_service.dart' show ApiException, ApiService;
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';

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
  String? _filterTier; // null=Todos, 'to_conquer'=A conquistar, 'bronze','silver','gold'
  String? _filterAwardKind; // null=Todos, 'medal', 'trophy'
  bool _loading = true;
  String? _error;
  bool _galleryVisible = true;

  bool get _isOwnGallery =>
      AuthService().currentUser?.id == widget.userId;

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
        return name.contains(query) || techniqueName.contains(query);
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
      filtered = filtered.where((t) => t.awardKind == _filterAwardKind).toList();
    }
    setState(() => _filteredItems = filtered);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getTrophiesForUser(widget.userId);
      if (mounted) setState(() {
        _allItems = list;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException && e.statusCode == 403
            ? 'Esta galeria está privada.'
            : userFacingMessage(e);
        setState(() { _error = msg; _loading = false; });
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
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
      case 'gold': return const Color(0xFFD97706);
      case 'silver': return const Color(0xFF6B7280);
      case 'bronze': return const Color(0xFF92400E);
      default: return AppTheme.textMuted;
    }
  }

  static IconData _tierIcon(String? tier) {
    switch (tier) {
      case 'gold': return Icons.emoji_events;
      case 'silver': return Icons.emoji_events;
      case 'bronze': return Icons.emoji_events;
      default: return Icons.workspace_premium_outlined;
    }
  }

  Future<String?> _showUsageTypeDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PointerInterceptor(
        child: AlertDialog(
          title: const Text('Quando você aplicou a técnica?'),
          content: const Text(
            'Em que momento você executou esta técnica?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'before_training'),
              child: const Text('Antes do treino'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'after_training'),
              child: const Text('Depois do treino'),
            ),
          ],
        ),
      ),
    );
  }

  static String _faixaLabel(String? g) {
    if (g == null || g.isEmpty) return '—';
    switch (g.toLowerCase()) {
      case 'white': return 'Branca';
      case 'blue': return 'Azul';
      case 'purple': return 'Roxa';
      case 'brown': return 'Marrom';
      case 'black': return 'Preta';
      default: return g;
    }
  }

  Future<String?> _showOpponentDialog(String academyId) async {
    List<UserModel> colleagues = [];
    try {
      final list = await _api.getUsers(academyId: academyId);
      colleagues = list.where((u) => u.id != widget.userId).toList();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível carregar colegas da academia.')),
        );
      }
      return null;
    }
    if (colleagues.isEmpty) return null;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PointerInterceptor(
        child: AlertDialog(
          title: const Text('Em quem você aplicou a técnica?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: colleagues.map<Widget>((u) {
                return ListTile(
                  title: Text(u.name ?? u.email),
                  subtitle: Text(_faixaLabel(u.graduation)),
                  onTap: () => Navigator.pop(ctx, u.id),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _indicateOpponent(TrophyWithEarned t) async {
    final academyId = t.academyId;
    if (academyId == null || academyId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Academia não definida para este troféu.')),
        );
      }
      return;
    }
    final usageType = await _showUsageTypeDialog();
    if (usageType == null || !mounted) return;
    final opponentId = await _showOpponentDialog(academyId);
    if (opponentId == null || !mounted) return;
    try {
      final res = await _api.postExecution(
        techniqueId: t.techniqueId,
        academyId: academyId,
        opponentId: opponentId,
        usageType: usageType,
      );
      if (!mounted) return;
      final message = res['message'] as String? ?? 'Aguardando confirmação do adversário.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.primary),
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  /// Linhas de progresso por tier (só para tiers ainda não conquistados).
  List<Widget> _progressLines(BuildContext context, TrophyWithEarned t) {
    final style = TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context));
    final lines = <Widget>[];
    final target = t.targetCount;
    final hasGold = t.earnedTier == 'gold';
    final hasSilver = t.earnedTier == 'silver' || hasGold;
    final hasBronze = t.earnedTier == 'bronze' || hasSilver;
    if (hasGold) {
      lines.add(Text('Conquistado: ouro', style: style.copyWith(fontWeight: FontWeight.w600, color: _tierColor('gold'))));
      return lines;
    }
    if (!hasBronze) {
      final missing = target - t.bronzeCount;
      if (missing > 0) {
        lines.add(Text(
          '${t.bronzeCount} adversários brancos distintos. Faltam $missing para o troféu bronze.',
          style: style,
        ));
      }
    }
    if (!hasSilver) {
      final missing = target - t.silverCount;
      if (missing > 0) {
        lines.add(Text(
          '${t.silverCount} azuis contabilizados. Faltam $missing para o troféu prata.',
          style: style,
        ));
      }
    }
    if (!hasGold) {
      final missing = target - t.goldCount;
      if (missing > 0) {
        lines.add(Text(
          '${t.goldCount} em roxa/marrom/preta. Faltam $missing para o troféu ouro.',
          style: style,
        ));
      }
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Galeria de troféus e medalhas'),
            if (widget.userName != null && widget.userName!.isNotEmpty)
              Text(
                widget.userName!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
                        style: TextStyle(color: AppTheme.textSecondary),
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
                                            color: AppTheme.textSecondaryOf(context),
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
                                      setState(() => _filterAwardKind = selected ? 'medal' : null);
                                      _applyFilters();
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('Troféus'),
                                    selected: _filterAwardKind == 'trophy',
                                    onSelected: (selected) {
                                      setState(() => _filterAwardKind = selected ? 'trophy' : null);
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
                                        setState(() => _filterTier = selected ? 'to_conquer' : null);
                                        _applyFilters();
                                      },
                                    ),
                                  FilterChip(
                                    label: const Text('Bronze'),
                                    selected: _filterTier == 'bronze',
                                    onSelected: (selected) {
                                      setState(() => _filterTier = selected ? 'bronze' : null);
                                      _applyFilters();
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('Prata'),
                                    selected: _filterTier == 'silver',
                                    onSelected: (selected) {
                                      setState(() => _filterTier = selected ? 'silver' : null);
                                      _applyFilters();
                                    },
                                  ),
                                  FilterChip(
                                    label: const Text('Ouro'),
                                    selected: _filterTier == 'gold',
                                    onSelected: (selected) {
                                      setState(() => _filterTier = selected ? 'gold' : null);
                                      _applyFilters();
                                    },
                                  ),
                                ],
                              ),
                              if (_searchController.text.isNotEmpty || _filterTier != null || _filterAwardKind != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Mostrando ${_filteredItems.length} de ${_allItems.length}',
                                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                                      _searchController.text.isNotEmpty || _filterTier != null || _filterAwardKind != null
                                          ? 'Nenhuma premiação encontrada.'
                                          : 'Nenhuma premiação cadastrada na sua academia.',
                                      style: TextStyle(color: AppTheme.textSecondary),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredItems.length,
                                    itemBuilder: (context, i) {
                                      final t = _filteredItems[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: _tierColor(t.earnedTier).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          _tierIcon(t.earnedTier),
                                          color: _tierColor(t.earnedTier),
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    t.name,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: AppTheme.textPrimaryOf(context),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: t.isTrophy
                                                        ? Theme.of(context).colorScheme.primaryContainer
                                                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    t.awardKindLabel,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w500,
                                                      color: t.isTrophy
                                                          ? Theme.of(context).colorScheme.onPrimaryContainer
                                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (t.techniqueName != null && t.techniqueName!.isNotEmpty)
                                              Text(
                                                t.techniqueName!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textSecondaryOf(context),
                                                ),
                                              ),
                                            Text(
                                              '${_formatDateRange(t.startDate, t.endDate)} · Meta: ${t.targetCount} execuções',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textMutedOf(context),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _tierColor(t.earnedTier).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          t.tierLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _tierColor(t.earnedTier),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  ...(){
                                    final progressLines = _progressLines(context, t);
                                    if (progressLines.isEmpty) return <Widget>[];
                                    return [
                                      const SizedBox(height: 10),
                                      ...progressLines.map((w) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: w,
                                      )),
                                    ];
                                  }(),
                                  if (_isOwnGallery &&
                                      t.academyId != null &&
                                      t.academyId!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.person_add, size: 18),
                                        label: const Text('Indicar adversário'),
                                        onPressed: () => _indicateOpponent(t),
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
