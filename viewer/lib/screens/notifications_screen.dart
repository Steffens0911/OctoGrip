import 'package:flutter/material.dart';
import 'package:viewer/features/photos/presentation/pages/photo_from_notification_screen.dart';
import 'package:viewer/models/notification_model.dart';
import 'package:viewer/services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _all = [];
  bool _loading = true;
  String? _error;
  String _filter = 'Todas';

  static const _filters = ['Todas', 'Missões', 'Troféus', 'Vídeos', 'Fotos', 'Avisos', 'Conta'];

  static const _typeToCategory = {
    'execution_indicated': 'Missões',
    'execution_confirmed': 'Missões',
    'execution_rejected': 'Missões',
    'execution_professor_approved': 'Missões',
    'execution_professor_rejected': 'Missões',
    'trophy_earned': 'Troféus',
    'trophy_social': 'Troféus',
    'trophy_new': 'Troféus',
    'video_new': 'Vídeos',
    'photo_comment': 'Fotos',
    'photo_mention': 'Fotos',
    'announcement_academy': 'Avisos',
    'announcement_global': 'Avisos',
    'account_frozen': 'Conta',
    'account_unfrozen': 'Conta',
  };

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
      final raw = await ApiService().getNotifications(limit: 100);
      setState(() {
        _all = raw.map(NotificationModel.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markRead(NotificationModel n) async {
    if (n.read) return;
    try {
      await ApiService().markNotificationRead(n.id);
      setState(() {
        final idx = _all.indexWhere((x) => x.id == n.id);
        if (idx != -1) _all[idx] = n.copyWith(read: true);
      });
    } catch (_) {}
  }

  void _navigateFromNotif(NotificationModel n) {
    if (n.type != 'photo_comment' && n.type != 'photo_mention') return;
    final data = n.data;
    if (data == null) return;
    final photoId = data['photo_id'] as String?;
    final academyId = data['academy_id'] as String?;
    if (photoId == null || academyId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoFromNotificationScreen(
          academyId: academyId,
          photoId: photoId,
        ),
      ),
    );
  }

  Future<void> _deleteNotification(NotificationModel n) async {
    try {
      await ApiService().deleteNotification(n.id);
      setState(() => _all.removeWhere((x) => x.id == n.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService().markAllNotificationsRead();
      setState(() {
        _all = _all.map((n) => n.copyWith(read: true)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  List<NotificationModel> get _filtered {
    if (_filter == 'Todas') return _all;
    return _all
        .where((n) => _typeToCategory[n.type] == _filter)
        .toList();
  }

  int get _unreadCount => _all.where((n) => !n.read).length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Marcar todas lidas',
                style: TextStyle(color: cs.primary, fontSize: 13),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterChips(
            filters: _filters,
            selected: _filter,
            onSelected: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _load)
                    : filtered.isEmpty
                        ? const _EmptyView()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _NotifTile(
                                notif: filtered[i],
                                onTap: () {
                                  _markRead(filtered[i]);
                                  _navigateFromNotif(filtered[i]);
                                },
                                onDelete: () => _deleteNotification(filtered[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ---- Filter chips ----

class _FilterChips extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final void Function(String) onSelected;

  const _FilterChips({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters
              .map(
                (f) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: selected == f,
                    onSelected: (_) => onSelected(f),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ---- Notification tile ----

class _NotifTile extends StatefulWidget {
  final NotificationModel notif;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotifTile({required this.notif, required this.onTap, required this.onDelete});

  @override
  State<_NotifTile> createState() => _NotifTileState();
}

class _NotifTileState extends State<_NotifTile> {
  bool _expanded = false;

  static const _typeIcon = {
    'execution_confirmed': ('✅', Color(0xFF2E7D32)),
    'execution_rejected': ('❌', Color(0xFFC62828)),
    'trophy_earned': ('🏆', Color(0xFFF9A825)),
    'trophy_social': ('🏅', Color(0xFF6A1B9A)),
    'trophy_new': ('🆕', Color(0xFF1565C0)),
    'video_new': ('🎬', Color(0xFF0277BD)),
    'photo_comment': ('💬', Color(0xFF0288D1)),
    'photo_mention': ('📸', Color(0xFF00897B)),
    'announcement_academy': ('📢', Color(0xFFE65100)),
    'announcement_global': ('📣', Color(0xFFB71C1C)),
    'account_frozen': ('🔒', Color(0xFFC62828)),
    'account_unfrozen': ('🔓', Color(0xFF2E7D32)),
  };

  // Retorna true se o body precisar de expansão (mais de 2 linhas ~80 chars)
  bool _needsExpansion(String body) => body.length > 80;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final notif = widget.notif;
    final (emoji, color) = _typeIcon[notif.type] ?? ('🔔', cs.primary);
    final isUnread = !notif.read;
    final canExpand = _needsExpansion(notif.body);

    return InkWell(
      onTap: () {
        widget.onTap();
        if (canExpand) setState(() => _expanded = !_expanded);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isUnread
              ? cs.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          border: Border(
            left: isUnread
                ? BorderSide(color: cs.primary, width: 3)
                : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isUnread ? FontWeight.w700 : FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: _expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Text(
                      notif.body,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    secondChild: Text(
                      notif.body,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                  if (canExpand) ...[
                    const SizedBox(height: 2),
                    Text(
                      _expanded ? 'ver menos' : 'ver mais',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(notif.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUnread)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8, bottom: 4),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Excluir notificação',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return 'há ${diff.inDays} dias';
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}

// ---- Empty / Error views ----

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'Nenhuma notificação',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}
