import 'package:flutter/material.dart';

import 'package:viewer/features/photos/presentation/pages/blocked_users_screen.dart';
import 'package:viewer/features/photos/presentation/pages/photo_reports_screen.dart';
import 'package:viewer/models/photo_moderation.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';

/// Chamado depois de denunciar ou bloquear: some um post (`photoId`), um comentário (`commentId`)
/// ou tudo de um autor (`blockedAuthorId`).
typedef ContentHiddenCallback = void Function({
  String? photoId,
  String? commentId,
  String? blockedAuthorId,
});

/// Abre a caixa de denúncia. Devolve `true` se a denúncia foi enviada.
/// Com [commentId] denuncia o comentário; sem ele, o post.
Future<bool> showReportDialog(
  BuildContext context, {
  required String academyId,
  required String photoId,
  String? commentId,
}) async {
  final result = await showDialog<_ReportInput>(
    context: context,
    builder: (_) => _ReportDialog(isComment: commentId != null),
  );
  if (result == null || !context.mounted) return false;
  try {
    final api = ApiService();
    if (commentId == null) {
      await api.reportPhoto(academyId, photoId,
          reason: result.reason, details: result.details);
    } else {
      await api.reportPhotoComment(academyId, photoId, commentId,
          reason: result.reason, details: result.details);
    }
    if (context.mounted) {
      AppFeedback.show(
        context,
        message:
            'Denúncia enviada. Os gestores da academia vão analisar e o conteúdo some do seu feed.',
        type: AppFeedbackType.success,
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      AppFeedback.show(context,
          message: userFacingMessage(e), type: AppFeedbackType.error);
    }
    return false;
  }
}

/// Pede confirmação e bloqueia o usuário. Devolve `true` se bloqueou.
Future<bool> confirmAndBlockUser(
  BuildContext context, {
  required String academyId,
  required String userId,
  required String userName,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Bloquear $userName?'),
      content: const Text(
        'Você deixa de ver os posts e comentários dessa pessoa. '
        'Ela não é avisada. Para desfazer, use "Usuários bloqueados" no feed de fotos.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Bloquear'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    await ApiService().blockPhotoUser(academyId, userId);
    if (context.mounted) {
      AppFeedback.show(context,
          message: '$userName bloqueado.', type: AppFeedbackType.success);
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      AppFeedback.show(context,
          message: userFacingMessage(e), type: AppFeedbackType.error);
    }
    return false;
  }
}

/// Itens "Denunciar" e "Bloquear" para o menu de um post ou comentário de outra pessoa.
/// [sheetContext] é o contexto da bottom sheet (fechada ao tocar); [context] continua válido depois.
List<Widget> moderationMenuTiles(
  BuildContext context,
  BuildContext sheetContext, {
  required String academyId,
  required String photoId,
  String? commentId,
  required String authorId,
  required String? authorName,
  required bool isOwn,
  required ContentHiddenCallback? onHidden,
}) {
  if (isOwn || authorId.isEmpty) return const [];
  final name = authorName ?? 'este usuário';
  final what = commentId == null ? 'post' : 'comentário';
  return [
    ListTile(
      leading: const Icon(Icons.flag_outlined),
      title: Text('Denunciar $what'),
      onTap: () async {
        Navigator.pop(sheetContext);
        final reported = await showReportDialog(
          context,
          academyId: academyId,
          photoId: photoId,
          commentId: commentId,
        );
        if (reported) {
          onHidden?.call(
            photoId: commentId == null ? photoId : null,
            commentId: commentId,
          );
        }
      },
    ),
    ListTile(
      leading: const Icon(Icons.block, color: Colors.red),
      title: Text('Bloquear $name', style: const TextStyle(color: Colors.red)),
      onTap: () async {
        Navigator.pop(sheetContext);
        final blocked = await confirmAndBlockUser(
          context,
          academyId: academyId,
          userId: authorId,
          userName: name,
        );
        if (blocked) onHidden?.call(blockedAuthorId: authorId);
      },
    ),
  ];
}

class _ReportInput {
  const _ReportInput(this.reason, this.details);
  final String reason;
  final String? details;
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.isComment});
  final bool isComment;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _reason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isComment ? 'Denunciar comentário' : 'Denunciar post'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Qual é o problema?'),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final e in kPhotoReportReasons.entries)
                    RadioListTile<String>(
                      key: Key('report-reason-${e.key}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: e.key,
                      title: Text(e.value),
                    ),
                ],
              ),
            ),
            TextField(
              key: const Key('report-details'),
              controller: _details,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Detalhes (opcional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('report-send'),
          onPressed: _reason == null
              ? null
              : () => Navigator.pop(
                    context,
                    _ReportInput(
                      _reason!,
                      _details.text.trim().isEmpty
                          ? null
                          : _details.text.trim(),
                    ),
                  ),
          child: const Text('Enviar denúncia'),
        ),
      ],
    );
  }
}

/// Faixa no topo do feed com os atalhos "Usuários bloqueados" e, para gestores, "Denúncias".
/// Fica visível mesmo com o feed vazio: quem bloqueou todo mundo ainda consegue desbloquear.
class PhotosModerationBar extends StatelessWidget {
  const PhotosModerationBar({
    super.key,
    required this.academyId,
    required this.isModerator,
    this.onChanged,
  });

  final String academyId;
  final bool isModerator;

  /// Chamado ao voltar de uma das telas (o feed pode ter mudado: desbloqueio, conteúdo removido).
  final VoidCallback? onChanged;

  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 4,
        children: [
          if (isModerator)
            TextButton.icon(
              key: const Key('open-reports'),
              onPressed: () =>
                  _open(context, PhotoReportsScreen(academyId: academyId)),
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('Denúncias'),
            ),
          TextButton.icon(
            key: const Key('open-blocked'),
            onPressed: () =>
                _open(context, BlockedUsersScreen(academyId: academyId)),
            icon: const Icon(Icons.block, size: 18),
            label: const Text('Bloqueados'),
          ),
        ],
      ),
    );
  }
}
