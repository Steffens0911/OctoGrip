import 'package:flutter/material.dart';

import 'package:viewer/models/photo_moderation.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Lista de usuários que o aluno bloqueou no feed de fotos, com opção de desbloquear.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key, required this.academyId});

  final String academyId;

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late Future<List<BlockedUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getBlockedPhotoUsers(widget.academyId);
  }

  void _reload() {
    setState(() {
      _future = ApiService().getBlockedPhotoUsers(widget.academyId);
    });
  }

  Future<void> _unblock(BlockedUser user) async {
    try {
      await ApiService().unblockPhotoUser(widget.academyId, user.userId);
      if (!mounted) return;
      AppFeedback.show(context,
          message: '${user.name ?? 'Usuário'} desbloqueado.',
          type: AppFeedbackType.success);
      _reload();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(context,
          message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Usuários bloqueados'),
      body: FutureBuilder<List<BlockedUser>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(userFacingMessage(snap.error!),
                    textAlign: TextAlign.center),
              ),
            );
          }
          final users = snap.data ?? const <BlockedUser>[];
          if (users.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Você não bloqueou ninguém.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = users[i];
              final name = u.name ?? 'Usuário';
              return ListTile(
                key: Key('blocked-${u.userId}'),
                leading: CircleAvatar(
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                ),
                title: Text(name),
                trailing: TextButton(
                  key: Key('unblock-${u.userId}'),
                  onPressed: () => _unblock(u),
                  child: const Text('Desbloquear'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
