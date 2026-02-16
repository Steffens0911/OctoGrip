import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getPointsLog(widget.userId, limit: 100);
      final list = data['entries'] as List<dynamic>? ?? [];
      if (mounted) setState(() {
        _entries = list.map((e) => e as Map<String, dynamic>).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Log de pontuação'),
            if (widget.userName != null && widget.userName!.isNotEmpty)
              Text(
                widget.userName!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
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
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
                      ],
                    ),
                  ),
                )
              : _entries.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum registro de pontuação.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
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
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                                child: Text(
                                  '+$points',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                ),
                              ),
                              title: Text(description, style: const TextStyle(fontSize: 14)),
                              subtitle: Text(
                                _formatDate(date),
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              trailing: source == 'execution'
                                  ? Icon(Icons.how_to_reg, size: 20, color: Colors.green.shade700)
                                  : Icon(Icons.flag, size: 20, color: AppTheme.primary),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
