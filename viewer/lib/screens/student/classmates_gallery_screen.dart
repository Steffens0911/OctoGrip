import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/trophy.dart';
import 'package:viewer/models/user.dart' as models;
import 'package:viewer/features/trophy_shelf/presentation/trophy_shelf_page.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/theme/fantasy_theme.dart';

/// Lista colegas da academia com troféus conquistados, busca e filtro por faixa.
class ClassmatesGalleryScreen extends StatefulWidget {
  final String academyId;
  final String? currentUserId;

  const ClassmatesGalleryScreen({
    super.key,
    required this.academyId,
    this.currentUserId,
  });

  @override
  State<ClassmatesGalleryScreen> createState() =>
      _ClassmatesGalleryScreenState();
}

class _ClassmatesGalleryScreenState extends State<ClassmatesGalleryScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();

  List<models.UserModel> _users = [];
  Map<String, List<AcademyUserEarnedItem>> _earnedMap = {};
  bool _loading = true;
  String? _error;
  String _filterGraduation = 'all';
  String _search = '';

  static const _graduations = [
    ('all', 'Todos'),
    ('white', 'Branca'),
    ('blue', 'Azul'),
    ('purple', 'Roxa'),
    ('brown', 'Marrom'),
    ('black', 'Preta'),
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getUsersAll(academyId: widget.academyId),
        _api.getAcademyEarned(widget.academyId),
      ]);
      if (mounted) {
        setState(() {
          _users = results[0] as List<models.UserModel>;
          _earnedMap = results[1] as Map<String, List<AcademyUserEarnedItem>>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(e);
          _loading = false;
        });
      }
    }
  }

  List<models.UserModel> get _filtered {
    return _users.where((u) {
      if (_filterGraduation != 'all') {
        final g = (u.graduation ?? '').toLowerCase();
        if (g != _filterGraduation) return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final name = (u.name ?? u.email).toLowerCase();
        if (!name.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  static String _faixaLabel(String? g) {
    switch (g?.toLowerCase()) {
      case 'white': return 'Branca';
      case 'blue': return 'Azul';
      case 'purple': return 'Roxa';
      case 'brown': return 'Marrom';
      case 'black': return 'Preta';
      default: return '';
    }
  }

  static Color _graduationColor(String? g, BuildContext context) {
    switch (g?.toLowerCase()) {
      case 'white': return Colors.grey.shade400;
      case 'blue': return Colors.blue.shade600;
      case 'purple': return Colors.purple.shade500;
      case 'brown': return Colors.brown.shade500;
      case 'black': return Colors.grey.shade800;
      default: return Colors.grey.shade500;
    }
  }

  static Color _avatarBg(String? g) {
    switch (g?.toLowerCase()) {
      case 'white': return Colors.grey.shade300;
      case 'blue': return Colors.blue.shade700;
      case 'purple': return Colors.purple.shade700;
      case 'brown': return Colors.brown.shade600;
      case 'black': return Colors.grey.shade800;
      default: return Colors.grey.shade600;
    }
  }

  static String _initials(String? name, String email) {
    final src = (name != null && name.trim().isNotEmpty) ? name.trim() : email;
    final parts = src.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return src.substring(0, src.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Galeria dos colegas'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    _SearchAndFilters(
                      controller: _searchCtrl,
                      selected: _filterGraduation,
                      graduations: _graduations,
                      onSelect: (v) => setState(() => _filterGraduation = v),
                    ),
                    _AthleteCount(count: _filtered.length),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: _filtered.isEmpty
                            ? const _EmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: _filtered.length,
                                itemBuilder: (context, i) {
                                  final u = _filtered[i];
                                  final earned = _earnedMap[u.id] ?? [];
                                  return _AthleteCard(
                                    user: u,
                                    earned: earned,
                                    isCurrentUser: u.id == widget.currentUserId,
                                    avatarBg: _avatarBg(u.graduation),
                                    graduationColor: _graduationColor(u.graduation, context),
                                    graduationLabel: _faixaLabel(u.graduation),
                                    initials: _initials(u.name, u.email),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TrophyShelfPage(
                                          userId: u.id,
                                          userName: u.name ?? u.email,
                                        ),
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

// ── Barra de busca + chips de faixa ──────────────────────────────────────────

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.selected,
    required this.graduations,
    required this.onSelect,
  });

  final TextEditingController controller;
  final String selected;
  final List<(String, String)> graduations;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Buscar colega...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderOf(context)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (value, label) in graduations) ...[
                  _FilterChip(
                    label: label,
                    selected: selected == value,
                    onTap: () => onSelect(value),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.primary : AppTheme.borderOf(context),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected
                    ? scheme.onPrimary
                    : AppTheme.textMutedOf(context),
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

// ── Contagem de atletas ───────────────────────────────────────────────────────

class _AthleteCount extends StatelessWidget {
  const _AthleteCount({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$count ${count == 1 ? 'ATLETA' : 'ATLETAS'}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textMutedOf(context),
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

// ── Card do atleta ────────────────────────────────────────────────────────────

class _AthleteCard extends StatelessWidget {
  const _AthleteCard({
    required this.user,
    required this.earned,
    required this.isCurrentUser,
    required this.avatarBg,
    required this.graduationColor,
    required this.graduationLabel,
    required this.initials,
    required this.onTap,
  });

  final models.UserModel user;
  final List<AcademyUserEarnedItem> earned;
  final bool isCurrentUser;
  final Color avatarBg;
  final Color graduationColor;
  final String graduationLabel;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10.5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: AppTheme.borderOf(context), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarBg,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
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
                              user.name ?? user.email,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: FantasyTheme.textPrimaryOf(context),
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Você',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (graduationLabel.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: graduationColor,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              graduationLabel,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMutedOf(context),
                                    fontSize: 11,
                                  ),
                            ),
                          ],
                        ),
                      ],
                      if (earned.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            for (final item in earned.take(4))
                              _TrophyPill(label: '${item.emoji} ${item.name}', style: labelStyle),
                            if (earned.length > 4)
                              Text('+${earned.length - 4}',
                                  style: labelStyle?.copyWith(
                                      color: AppTheme.textMutedOf(context))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: AppTheme.textMutedOf(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrophyPill extends StatelessWidget {
  const _TrophyPill({required this.label, this.style});
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Estados auxiliares ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Text(
            'Nenhum colega encontrado.',
            style: TextStyle(color: AppTheme.textSecondaryOf(context)),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}
