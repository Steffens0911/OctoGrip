import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/audit_history.dart';
import 'package:viewer/services/admin_audit_service.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/widgets/role_guard.dart';

const _entityChoices = <MapEntry<String, String>>[
  MapEntry('mission', 'Missão'),
  MapEntry('lesson', 'Lição'),
  MapEntry('technique', 'Técnica'),
  MapEntry('trophy', 'Troféu'),
];

const JsonEncoder _jsonPretty = JsonEncoder.withIndent('  ');

/// Feed de auditoria e restauração (somente administrador): filtros por
/// academia, tipo de entidade e ação; restauração a partir de cada log.
class AuditRecoveryScreen extends StatefulWidget {
  const AuditRecoveryScreen({super.key});

  @override
  State<AuditRecoveryScreen> createState() => _AuditRecoveryScreenState();
}

class _AuditRecoveryScreenState extends State<AuditRecoveryScreen> {
  final _service = AdminAuditService();
  final _api = ApiService();

  List<Academy> _academies = [];
  bool _academiesLoading = false;
  String? _feedAcademyId;
  String _feedEntity = '';
  String _feedOrder = 'desc';
  String _feedAction = '';
  final List<AuditLogItem> _feedItems = [];
  int _feedTotal = 0;
  int _feedOffset = 0;
  bool _feedLoading = false;
  String? _feedError;
  static const int _feedPageSize = 40;

  @override
  void initState() {
    super.initState();
    _loadAcademies();
  }

  Future<void> _loadAcademies() async {
    setState(() => _academiesLoading = true);
    try {
      final list = await _api.getAcademies();
      if (mounted) {
        setState(() {
          _academies = list;
          _academiesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _academiesLoading = false);
      }
    }
  }

  Future<void> _loadFeed({bool append = false}) async {
    setState(() {
      _feedLoading = true;
      _feedError = null;
      if (!append) {
        _feedItems.clear();
        _feedOffset = 0;
      }
    });
    try {
      final off = append ? _feedOffset : 0;
      final r = await _service.fetchFeed(
        academyId: _feedAcademyId,
        entity: _feedEntity.isEmpty ? null : _feedEntity,
        limit: _feedPageSize,
        offset: off,
        action: _feedAction.isEmpty ? null : _feedAction,
        order: _feedOrder,
      );
      if (!mounted) return;
      setState(() {
        if (append) {
          _feedItems.addAll(r.items);
        } else {
          _feedItems
            ..clear()
            ..addAll(r.items);
        }
        _feedTotal = r.total;
        _feedOffset = off + r.items.length;
        _feedLoading = false;
      });
    } on AdminAuditServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _feedError = e.message;
        _feedLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedError = e.toString();
        _feedLoading = false;
      });
    }
  }

  Future<void> _loadMoreFeed() async {
    if (_feedLoading || _feedItems.length >= _feedTotal) return;
    await _loadFeed(append: true);
  }

  Future<void> _reloadFeedAfterRestore() async {
    await _loadFeed(append: false);
  }

  Future<void> _undeleteFromFeed(String entityApiKey, String entityId) async {
    setState(() {
      _feedLoading = true;
      _feedError = null;
    });
    try {
      await _service.restore(entity: entityApiKey, entityId: entityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro reativado.')),
        );
      }
      await _reloadFeedAfterRestore();
    } on AdminAuditServiceException catch (e) {
      if (mounted) {
        setState(() {
          _feedError = e.message;
          _feedLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedError = e.toString();
          _feedLoading = false;
        });
      }
    }
  }

  Future<void> _restoreSnapshotFromFeed(
    String entityApiKey,
    String entityId,
    String auditLogId,
  ) async {
    setState(() {
      _feedLoading = true;
      _feedError = null;
    });
    try {
      await _service.restore(
        entity: entityApiKey,
        entityId: entityId,
        auditLogId: auditLogId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Versão restaurada a partir do log.')),
        );
      }
      await _reloadFeedAfterRestore();
    } on AdminAuditServiceException catch (e) {
      if (mounted) {
        setState(() {
          _feedError = e.message;
          _feedLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedError = e.toString();
          _feedLoading = false;
        });
      }
    }
  }

  static String _apiEntityFromLogLabel(String label) {
    switch (label) {
      case 'Mission':
        return 'mission';
      case 'Lesson':
        return 'lesson';
      case 'Technique':
        return 'technique';
      case 'Trophy':
        return 'trophy';
      default:
        return label.toLowerCase();
    }
  }

  static String _entityLabelPt(String label) {
    switch (label) {
      case 'Mission':
        return 'Missão';
      case 'Lesson':
        return 'Lição';
      case 'Technique':
        return 'Técnica';
      case 'Trophy':
        return 'Troféu';
      default:
        return label;
    }
  }

  static String? _summaryFromPayload(AuditLogItem item) {
    final newD = item.newData;
    final oldD = item.oldData;
    String? pick(Map<String, dynamic>? m) {
      if (m == null) return null;
      final name = m['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
      final title = m['title']?.toString();
      if (title != null && title.isNotEmpty) return title;
      return null;
    }

    return pick(newD) ?? pick(oldD);
  }

  String _formatDt(String iso) {
    final d = DateTime.tryParse(iso.replaceFirst('Z', '+00:00'));
    if (d == null) return iso;
    return '${d.toLocal()}';
  }

  String _prettyJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return '—';
    try {
      return _jsonPretty.convert(map);
    } catch (_) {
      return map.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['administrador'],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Auditoria e recuperação'),
        ),
        body: _buildFeedTab(context),
      ),
    );
  }

  Widget _buildFeedTab(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(AppTheme.screenPadding(context)),
      children: [
        Text(
          'Todas as alterações auditadas (missões, lições, técnicas, troféus). '
          'Filtre por academia para ver só o que afeta essa unidade.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryOf(context),
              ),
        ),
        const SizedBox(height: 16),
        if (_academiesLoading)
          const LinearProgressIndicator()
        else
          _outlineDropdown<String?>(
            label: 'Academia',
            value: _feedAcademyId,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas as academias'),
              ),
              ..._academies.map(
                (a) => DropdownMenuItem<String?>(
                  value: a.id,
                  child: Text(a.name),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _feedAcademyId = v),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _outlineDropdown<String>(
                label: 'Tipo de entidade',
                value: _feedEntity.isEmpty ? '' : _feedEntity,
                items: [
                  const DropdownMenuItem(value: '', child: Text('Todas')),
                  ..._entityChoices.map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _feedEntity = v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _outlineDropdown<String>(
                label: 'Ordem',
                value: _feedOrder,
                items: const [
                  DropdownMenuItem(
                    value: 'desc',
                    child: Text('Mais recente primeiro'),
                  ),
                  DropdownMenuItem(
                    value: 'asc',
                    child: Text('Mais antigo primeiro'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _feedOrder = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _outlineDropdown<String>(
          label: 'Filtrar ação',
          value: _feedAction.isEmpty ? '' : _feedAction,
          items: const [
            DropdownMenuItem(value: '', child: Text('Todas')),
            DropdownMenuItem(value: 'CREATE', child: Text('CREATE')),
            DropdownMenuItem(value: 'UPDATE', child: Text('UPDATE')),
            DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
            DropdownMenuItem(value: 'RESTORE', child: Text('RESTORE')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _feedAction = v);
          },
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _feedLoading ? null : () => _loadFeed(append: false),
          icon: _feedLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.rss_feed_rounded),
          label: const Text('Carregar feed'),
        ),
        if (_feedError != null) ...[
          const SizedBox(height: 16),
          Material(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _feedError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
        ],
        if (_feedItems.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Exibindo ${_feedItems.length} de $_feedTotal',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimaryOf(context),
                ),
          ),
          const SizedBox(height: 8),
          ..._feedItems.map(
            (item) => _buildLogCard(
              context,
              item,
              summaryLine: _summaryFromPayload(item),
              busy: _feedLoading,
              onRestoreSnapshot: (logId) => _restoreSnapshotFromFeed(
                _apiEntityFromLogLabel(item.entity),
                item.entityId,
                logId,
              ),
              onUndelete: item.action == 'DELETE'
                  ? () => _undeleteFromFeed(
                        _apiEntityFromLogLabel(item.entity),
                        item.entityId,
                      )
                  : null,
            ),
          ),
          if (_feedItems.length < _feedTotal)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              child: OutlinedButton.icon(
                onPressed: _feedLoading ? null : _loadMoreFeed,
                icon: const Icon(Icons.expand_more),
                label: const Text('Carregar mais'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _outlineDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildLogCard(
    BuildContext context,
    AuditLogItem item, {
    String? summaryLine,
    required bool busy,
    required Future<void> Function(String auditLogId) onRestoreSnapshot,
    void Function()? onUndelete,
  }) {
    final canSnapshot = (item.action == 'UPDATE' || item.action == 'DELETE') &&
        item.oldData != null &&
        item.oldData!.isNotEmpty;
    final subtitle = summaryLine != null && summaryLine.isNotEmpty
        ? summaryLine
        : '${item.entityId.substring(0, 8)}…';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_entityLabelPt(item.entity)} · $subtitle',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimaryOf(context),
                  ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Chip(
                  label: Text(item.action),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDt(item.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMutedOf(context),
                        ),
                  ),
                ),
              ],
            ),
            if (item.userId != null)
              Text(
                'Usuário: ${item.userId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Text(
              'Registro: ${item.entityId}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMutedOf(context),
                  ),
            ),
            Text(
              'Log id: ${item.id}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMutedOf(context),
                  ),
            ),
            if (onUndelete != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: busy ? null : onUndelete,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Reativar registro'),
                ),
              ),
            if (canSnapshot)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: busy ? null : () => onRestoreSnapshot(item.id),
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const Text('Restaurar esta versão'),
                ),
              ),
            ExpansionTile(
              title: const Text('old_data / new_data'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    'old_data:\n${_prettyJson(item.oldData)}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    'new_data:\n${_prettyJson(item.newData)}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
