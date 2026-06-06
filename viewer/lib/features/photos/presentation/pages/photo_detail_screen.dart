import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:viewer/models/academy_photo.dart';
import 'package:viewer/services/api_service.dart';

class PhotoDetailScreen extends StatefulWidget {
  const PhotoDetailScreen({
    super.key,
    required this.photo,
    required this.academyId,
    required this.currentUserId,
    required this.isModerator,
    required this.onLike,
    required this.onUnlike,
    required this.onDelete,
  });

  final AcademyPhoto photo;
  final String academyId;
  final String currentUserId;
  final bool isModerator;
  final VoidCallback onLike;
  final VoidCallback onUnlike;
  final VoidCallback onDelete;

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  late AcademyPhoto _photo;
  List<PhotoComment> _comments = [];
  bool _loadingComments = true;
  bool _sending = false;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  // Mention autocomplete state
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _showSuggestions = false;
  String _currentMentionQuery = '';
  Timer? _mentionDebounce;

  @override
  void initState() {
    super.initState();
    _photo = widget.photo;
    _controller.addListener(_onTextChanged);
    _loadComments();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _mentionDebounce?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;

    // Não depende do cursor (baseOffset retorna -1 no Flutter Web/mobile
    // durante composição IME). Busca @menção a partir do fim do texto.
    final match = RegExp(r'@([A-Za-zÀ-ÿ0-9_]*)$').firstMatch(text);

    if (match != null) {
      final query = match.group(1) ?? '';
      if (query != _currentMentionQuery) {
        _currentMentionQuery = query;
        _scheduleFetch(query);
      }
      if (!_showSuggestions) setState(() => _showSuggestions = true);
    } else {
      if (_showSuggestions || _mentionSuggestions.isNotEmpty) {
        setState(() {
          _showSuggestions = false;
          _mentionSuggestions = [];
          _currentMentionQuery = '';
        });
      }
    }
  }

  void _scheduleFetch(String query) {
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final suggestions =
            await ApiService().getMentionSuggestions(widget.academyId, query);
        if (mounted) setState(() => _mentionSuggestions = suggestions);
      } catch (_) {}
    });
  }

  void _insertMention(Map<String, dynamic> user) {
    final name = ((user['name'] as String?) ?? '').split(' ').first;
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset.clamp(0, text.length);
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final replaced =
        before.replaceAll(RegExp(r'@[A-Za-zÀ-ÿ0-9_]*$'), '@$name ');
    _controller.value = TextEditingValue(
      text: replaced + after,
      selection: TextSelection.collapsed(offset: replaced.length),
    );
    setState(() {
      _showSuggestions = false;
      _mentionSuggestions = [];
    });
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments =
          await ApiService().listComments(widget.academyId, _photo.id);
      if (mounted) setState(() => _comments = comments);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment =
          await ApiService().addComment(widget.academyId, _photo.id, text);
      _controller.clear();
      if (mounted) {
        setState(() {
          _comments.add(comment);
          _photo = _photo.copyWith(commentsCount: _photo.commentsCount + 1);
          _showSuggestions = false;
          _mentionSuggestions = [];
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(PhotoComment comment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir comentário'),
        content: const Text('Deseja remover este comentário?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService()
          .deleteComment(widget.academyId, _photo.id, comment.id);
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c.id == comment.id);
          _photo = _photo.copyWith(
              commentsCount: (_photo.commentsCount - 1).clamp(0, 9999));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }

  String _absoluteUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final base = ApiService().baseUrl;
    return raw.startsWith('/') ? '$base$raw' : raw;
  }

  bool _canDeleteComment(PhotoComment c) =>
      c.author.id == widget.currentUserId || widget.isModerator;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final imageUrl = _absoluteUrl(_photo.imageUrl ?? _photo.thumbnailUrl);

    return Scaffold(
      appBar: AppBar(title: const Text('Foto')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: [
                if (imageUrl.isNotEmpty)
                  InteractiveViewer(
                    panEnabled: false,
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(
                        height: 240,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, __, ___) => const SizedBox(
                        height: 240,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),

                if (_photo.caption != null &&
                    _photo.caption!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Text(_photo.caption!, style: tt.bodyMedium),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _photo.likedByMe
                              ? Icons.favorite_rounded
                              : Icons.favorite_border,
                          color: _photo.likedByMe ? Colors.red : null,
                        ),
                        onPressed:
                            _photo.likedByMe ? widget.onUnlike : widget.onLike,
                      ),
                      if (_photo.likesCount > 0)
                        Text('${_photo.likesCount}',
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 12),
                      Icon(Icons.chat_bubble_outline,
                          size: 20, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${_photo.commentsCount}',
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),

                const Divider(height: 1),

                if (_loadingComments)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('Nenhum comentário ainda.',
                          style:
                              TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  )
                else
                  ..._comments.map((c) => _CommentTile(
                        comment: c,
                        canDelete: _canDeleteComment(c),
                        onDelete: () => _deleteComment(c),
                      )),
              ],
            ),
          ),

          // Sugestões de @menção
          if (_showSuggestions && _mentionSuggestions.isNotEmpty)
            _MentionSuggestionList(
              suggestions: _mentionSuggestions,
              onSelect: _insertMention,
            ),

          // Input de comentário
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLength: 500,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Adicione um comentário...',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const SizedBox(
                          width: 40,
                          height: 40,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton.filled(
                          icon: const Icon(Icons.send_rounded),
                          onPressed: _sendComment,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lista de sugestões de @menção
// ---------------------------------------------------------------------------

class _MentionSuggestionList extends StatelessWidget {
  const _MentionSuggestionList({
    required this.suggestions,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> suggestions;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: suggestions.length,
        itemBuilder: (_, i) {
          final s = suggestions[i];
          final name = (s['name'] as String?) ?? '';
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: cs.primaryContainer,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
            title: Text(
              '@${name.split(' ').first}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.primary),
            ),
            subtitle: Text(name,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            onTap: () => onSelect(s),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile de comentário com highlight de @menções
// ---------------------------------------------------------------------------

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  final PhotoComment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  static final _mentionRe = RegExp(r'@([A-Za-zÀ-ÿ0-9_]+)');

  Widget _buildBody(BuildContext context, String body) {
    final cs = Theme.of(context).colorScheme;
    final base = DefaultTextStyle.of(context).style.copyWith(fontSize: 14);
    final spans = <TextSpan>[];
    int last = 0;
    for (final m in _mentionRe.allMatches(body)) {
      if (m.start > last) {
        spans.add(TextSpan(text: body.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(
            color: cs.primary, fontWeight: FontWeight.w600),
      ));
      last = m.end;
    }
    if (last < body.length) {
      spans.add(TextSpan(text: body.substring(last)));
    }
    return RichText(
      text: TextSpan(style: base, children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr =
        DateFormat('dd/MM HH:mm').format(comment.createdAt.toLocal());
    final name = comment.author.name ?? 'Aluno';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: cs.primaryContainer,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(dateStr,
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 2),
                _buildBody(context, comment.body),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              icon:
                  Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
