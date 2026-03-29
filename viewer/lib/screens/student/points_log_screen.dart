import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_screen_state.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Histórico de pontuação do usuário (execuções confirmadas e conclusões de missão).
class PointsLogScreen extends StatefulWidget {
  final String userId;
  final String? userName;

  const PointsLogScreen({super.key, required this.userId, this.userName});

  @override
  State<PointsLogScreen> createState() => _PointsLogScreenState();
}

class _PointsLogScreenState extends State<PointsLogScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;

  static String _sourceLabel(String source) {
    switch (source) {
      case 'execution':
        return 'Treino validado';
      case 'mission':
        return 'Missão concluída';
      case 'daily_video':
        return 'Consistência diária';
      default:
        return 'Evolução geral';
    }
  }

  static String _insightMessage(String source, int points) {
    if (source == 'execution') {
      return points >= 20
          ? 'Bom avanço técnico nesta confirmação.'
          : 'Ponto ganho por prática validada.';
    }
    if (source == 'mission') {
      return 'Missão finalizada: progresso de consistência semanal.';
    }
    if (source == 'daily_video') {
      return 'Hábito diário reforçado com revisão de conteúdo.';
    }
    return 'Pontuação registrada no seu progresso.';
  }

  static String _impactLabel(Map<String, dynamic> entry, String source, int points) {
    final rawLevel = (entry['impact_level'] ?? entry['quality_level'] ?? entry['impact'])?.toString().toLowerCase();
    if (rawLevel != null && rawLevel.isNotEmpty) {
      if (rawLevel.contains('high') || rawLevel.contains('alto')) return 'Impacto alto';
      if (rawLevel.contains('medium') || rawLevel.contains('medio') || rawLevel.contains('médio')) {
        return 'Impacto médio';
      }
      if (rawLevel.contains('low') || rawLevel.contains('baixo')) return 'Impacto baixo';
    }

    final rawScore = entry['quality_score'] ?? entry['impact_score'];
    if (rawScore is num) {
      if (rawScore >= 0.75) return 'Impacto alto';
      if (rawScore >= 0.45) return 'Impacto médio';
      return 'Impacto baixo';
    }

    if (source == 'mission') return 'Impacto médio';
    if (source == 'training_video' || source == 'daily_video') return 'Consistência';
    if (points >= 30) return 'Impacto alto';
    if (points >= 15) return 'Impacto médio';
    return 'Impacto baixo';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getPointsLog(widget.userId, limit: 100);
      final list = data['entries'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _entries = list.map((e) => e as Map<String, dynamic>).toList();
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

  static String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return iso;
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppStandardAppBar(
        title: 'Log de pontuação',
        subtitle:
            (widget.userName != null && widget.userName!.isNotEmpty)
                ? widget.userName
                : null,
      ),
      body: _loading
          ? const AppScreenState.loading()
          : _error != null
              ? AppScreenState.error(message: _error!, onRetry: _load)
              : _entries.isEmpty
                  ? const AppScreenState.empty(
                      message: 'Nenhum registro de pontuação.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _entries.length,
                        itemBuilder: (context, i) {
                          final e = _entries[i];
                          final date = e['date'] as String?;
                          final points = e['points'] as int? ?? 0;
                          final source = e['source'] as String? ?? '';
                          final description = e['description'] as String? ?? '';
                          final impactLabel = _impactLabel(e, source, points);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    AppTheme.primary.withValues(alpha: 0.2),
                                child: Text(
                                  '+$points',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary),
                                ),
                              ),
                              title: Text(description,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          _sourceLabel(source),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          impactLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatDate(date),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _insightMessage(source, points),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                              trailing: source == 'execution'
                                  ? Icon(Icons.how_to_reg,
                                      size: 20, color: Colors.green.shade700)
                                  : const Icon(Icons.flag,
                                      size: 20, color: AppTheme.primary),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
