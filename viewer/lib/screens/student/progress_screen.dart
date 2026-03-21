import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/mission_history_item.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

/// Todas as missões concluídas do usuário (GET /mission_usages/history).
class ProgressScreen extends StatefulWidget {
  final String userId;

  const ProgressScreen({super.key, required this.userId});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _api = ApiService();
  List<MissionHistoryItem> _items = [];
  bool _loading = true;
  String? _error;

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
      final list = await _api.getMissionUsagesHistory(limit: 500);
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = userFacingMessage(e);
        });
      }
    }
  }

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Hoje';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu progresso')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red.shade700)),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _load,
                            child: const Text('Tentar novamente')),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma missão concluída ainda.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Text(
                            'Todas as missões cumpridas (${_items.length})',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            itemBuilder: (context, i) {
                              final item = _items[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        AppTheme.primary.withValues(alpha: 0.2),
                                    child: const Icon(Icons.check_circle,
                                        color: AppTheme.primary),
                                  ),
                                  title: Text(item.lessonTitle,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    '${_formatDate(item.completedAt)} • ${item.usageType == 'before_training' ? 'Antes do treino' : 'Depois do treino'}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
