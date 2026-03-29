import 'package:file_saver/file_saver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';
import 'package:viewer/widgets/role_guard.dart';

/// Área de backup: exportar ZIP (SQL + mídia) ou só SQL; restaurar backup (destrutivo).
class DatabaseBackupScreen extends StatefulWidget {
  const DatabaseBackupScreen({super.key});

  @override
  State<DatabaseBackupScreen> createState() => _DatabaseBackupScreenState();
}

class _DatabaseBackupScreenState extends State<DatabaseBackupScreen> {
  final _api = ApiService();
  bool _loadingZip = false;
  bool _loadingSql = false;
  bool _restoring = false;
  String? _error;

  /// Mensagem da API + dicas para 503 (pg_dump / versão / restauração em curso).
  String _backupFailureMessage(ApiException e) {
    var m = e.message;
    if (e.statusCode == 503) {
      m = '$m\n\n'
          '• API no Docker: na raiz do projeto, rode docker compose build api e docker compose up -d api.\n'
          '• API com uvicorn no Windows: o pg_dump no PATH deve ser da mesma versão major do Postgres (ex.: 16). Ou use só a API do Docker na porta 8000.\n'
          '• Não baixe backup enquanto uma restauração estiver em andamento.';
    }
    return m;
  }

  Future<void> _downloadZip() async {
    setState(() {
      _loadingZip = true;
      _error = null;
    });
    try {
      final bytes = await _api.downloadBackupArchive();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final name = 'jjb_backup_$stamp';
      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        fileExtension: 'zip',
        mimeType: MimeType.custom,
        customMimeType: 'application/zip',
      );
      if (mounted) {
        AppFeedback.show(
          context,
          message: 'Backup ZIP salvo: $name.zip',
          type: AppFeedbackType.success,
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _backupFailureMessage(e));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingZip = false);
    }
  }

  Future<void> _downloadSqlOnly() async {
    setState(() {
      _loadingSql = true;
      _error = null;
    });
    try {
      final bytes = await _api.downloadDatabaseBackup();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final name = 'jjb_backup_$stamp';
      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        fileExtension: 'sql',
        mimeType: MimeType.custom,
        customMimeType: 'application/sql',
      );
      if (mounted) {
        AppFeedback.show(
          context,
          message: 'SQL salvo: $name.sql (sem mídia)',
          type: AppFeedbackType.success,
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _backupFailureMessage(e));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSql = false);
    }
  }

  Future<void> _pickAndRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _RestoreConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;

    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: kIsWeb,
    );
    if (pick == null || pick.files.isEmpty || !mounted) return;

    final f = pick.files.single;
    setState(() {
      _restoring = true;
      _error = null;
    });
    try {
      if (kIsWeb) {
        if (f.bytes == null) {
          throw Exception('Não foi possível ler o arquivo no navegador.');
        }
        await _api.restoreBackupZip(bytes: f.bytes!, filename: f.name);
      } else {
        final path = f.path;
        if (path != null && path.isNotEmpty) {
          await _api.restoreBackupZip(filePath: path, filename: f.name);
        } else if (f.bytes != null) {
          await _api.restoreBackupZip(bytes: f.bytes!, filename: f.name);
        } else {
          throw Exception('Caminho ou conteúdo do arquivo indisponível.');
        }
      }
      if (mounted) {
        AppFeedback.show(
          context,
          message: 'Restauração concluída. Evite usar o app até recarregar se algo parecer inconsistente.',
          type: AppFeedbackType.success,
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _backupFailureMessage(e));
    } catch (e) {
      if (mounted) setState(() => _error = userFacingMessage(e));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = AppTheme.screenPadding(context);
    return RoleGuard(
      allowedRoles: const ['administrador'],
      child: Scaffold(
        appBar: const AppStandardAppBar(
          title: 'Backup do banco de dados',
          subtitle: 'Exportar e restaurar',
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Exportar',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimaryOf(context),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'O backup completo é um arquivo ZIP com database.sql e a pasta media/ '
                '(logos e imagens de horários em app_media).',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: (_loadingZip || _loadingSql || _restoring) ? null : _downloadZip,
                icon: _loadingZip
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_zip_rounded),
                label: Text(_loadingZip ? 'Gerando ZIP…' : 'Baixar backup completo (.zip)'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: (_loadingZip || _loadingSql || _restoring) ? null : _downloadSqlOnly,
                icon: _loadingSql
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.description_outlined),
                label: Text(_loadingSql ? 'Gerando SQL…' : 'Baixar só SQL (avançado, sem mídia)'),
              ),
              const SizedBox(height: 32),
              Text(
                'Restaurar',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimaryOf(context),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Envia um ZIP gerado por este sistema (database.sql na raiz). '
                'Todos os dados atuais do banco serão apagados e substituídos. '
                'Se o ZIP incluir pasta media/ com arquivos, as mídias em app_media serão substituídas.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Durante a restauração, prefira não usar o sistema. '
                'Com "Atuar como", o pedido usa sempre a conta de administrador.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pode demorar vários minutos (bases grandes). Não feche o separador. '
                'Se o Chrome mostrar falha de rede, aguarde e reinicie a API se necessário.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: (_loadingZip || _loadingSql || _restoring) ? null : _pickAndRestore,
                icon: _restoring
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore_rounded),
                label: Text(_restoring ? 'Restaurando…' : 'Escolher .zip e restaurar'),
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                SelectableText(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreConfirmDialog extends StatefulWidget {
  const _RestoreConfirmDialog();

  @override
  State<_RestoreConfirmDialog> createState() => _RestoreConfirmDialogState();
}

class _RestoreConfirmDialogState extends State<_RestoreConfirmDialog> {
  final _controller = TextEditingController();
  bool _canContinue = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final ok = _controller.text.trim() == 'RESTAURAR';
      if (ok != _canContinue) {
        setState(() => _canContinue = ok);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar restauração'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Esta ação apaga o banco de dados atual e aplica o backup. '
              'Para continuar, digite exatamente:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'RESTAURAR',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Confirmação',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _canContinue ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Continuar e escolher arquivo'),
        ),
      ],
    );
  }
}
