import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/admin/partner_list_screen.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';

class AcademyCustomizationBusinessSections extends StatefulWidget {
  const AcademyCustomizationBusinessSections({
    super.key,
    required this.academy,
    required this.onUpdated,
  });

  final Academy academy;
  final VoidCallback onUpdated;

  @override
  State<AcademyCustomizationBusinessSections> createState() =>
      _AcademyCustomizationBusinessSectionsState();
}

class _AcademyCustomizationBusinessSectionsState
    extends State<AcademyCustomizationBusinessSections> {
  final ApiService _api = ApiService();
  late Academy _academy;

  late final TextEditingController _logoUrlController;
  bool _uploadingLogo = false;
  bool _uploadingScheduleImage = false;

  bool _showTrophies = true;
  bool _showPartners = true;
  bool _showSchedule = true;
  bool _showGlobalSupporters = true;
  bool _savingVisibility = false;

  int? _scheduleImageCacheBuster;

  late final TextEditingController _loginNoticeTitleController;
  late final TextEditingController _loginNoticeBodyController;
  late final TextEditingController _loginNoticeUrlController;
  bool _loginNoticeActive = false;
  bool _savingLoginNotice = false;

  @override
  void initState() {
    super.initState();
    _academy = widget.academy;
    _logoUrlController = TextEditingController(text: _academy.logoUrl ?? '');
    _showTrophies = _academy.showTrophies;
    _showPartners = _academy.showPartners;
    _showSchedule = _academy.showSchedule;
    _showGlobalSupporters = _academy.showGlobalSupporters;
    _loginNoticeTitleController =
        TextEditingController(text: _academy.loginNoticeTitle ?? '');
    _loginNoticeBodyController =
        TextEditingController(text: _academy.loginNoticeBody ?? '');
    _loginNoticeUrlController =
        TextEditingController(text: _academy.loginNoticeUrl ?? '');
    _loginNoticeActive = _academy.loginNoticeActive;
  }

  @override
  void didUpdateWidget(covariant AcademyCustomizationBusinessSections oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.academy.id != widget.academy.id ||
        oldWidget.academy.updatedAt != widget.academy.updatedAt) {
      _academy = widget.academy;
      _logoUrlController.text = _academy.logoUrl ?? '';
      _showTrophies = _academy.showTrophies;
      _showPartners = _academy.showPartners;
      _showSchedule = _academy.showSchedule;
      _showGlobalSupporters = _academy.showGlobalSupporters;
      _loginNoticeTitleController.text = _academy.loginNoticeTitle ?? '';
      _loginNoticeBodyController.text = _academy.loginNoticeBody ?? '';
      _loginNoticeUrlController.text = _academy.loginNoticeUrl ?? '';
      _loginNoticeActive = _academy.loginNoticeActive;
    }
  }

  @override
  void dispose() {
    _logoUrlController.dispose();
    _loginNoticeTitleController.dispose();
    _loginNoticeBodyController.dispose();
    _loginNoticeUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    setState(() => _uploadingLogo = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (!mounted) return;
        setState(() => _uploadingLogo = false);
        return;
      }
      final file = result.files.first;
      if (file.bytes == null) {
        if (!mounted) return;
        setState(() => _uploadingLogo = false);
        return;
      }
      final updated = await _api.uploadAcademyLogo(
        _academy.id,
        file.bytes!,
        file.name,
      );
      if (!mounted) return;
      setState(() {
        _academy = updated;
        _logoUrlController.text = updated.logoUrl ?? '';
        _uploadingLogo = false;
      });
      widget.onUpdated();
      AppFeedback.show(
        context,
        message: 'Brasão da academia atualizado.',
        type: AppFeedbackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingLogo = false);
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  Future<void> _pickAndUploadScheduleImage() async {
    setState(() => _uploadingScheduleImage = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (!mounted) return;
        setState(() => _uploadingScheduleImage = false);
        return;
      }
      final file = result.files.first;
      if (file.bytes == null) {
        if (!mounted) return;
        setState(() => _uploadingScheduleImage = false);
        return;
      }
      final updated = await _api.uploadAcademyScheduleImage(
        _academy.id,
        file.bytes!,
        file.name,
      );
      if (!mounted) return;
      setState(() {
        _academy = updated;
        _uploadingScheduleImage = false;
        _scheduleImageCacheBuster = DateTime.now().millisecondsSinceEpoch;
      });
      _api.invalidateCache('GET:${_api.baseUrl}/academies');
      widget.onUpdated();
      AppFeedback.show(
        context,
        message: 'Quadro de horários atualizado.',
        type: AppFeedbackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingScheduleImage = false);
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  String _scheduleImageUrlWithCacheBuster() {
    final raw = _academy.scheduleImageUrl!;
    final base = raw.startsWith('/') ? '${_api.baseUrl}$raw' : raw;
    final v = (_scheduleImageCacheBuster ?? _academy.updatedAt ?? '').toString();
    if (v.isEmpty) return base;
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}v=$v';
  }

  String _academyLogoFullUrl() {
    final raw = _academy.logoUrl!;
    return raw.startsWith('/') ? '${_api.baseUrl}$raw' : raw;
  }

  Future<void> _updateHomeVisibility({
    bool? showTrophies,
    bool? showPartners,
    bool? showSchedule,
    bool? showGlobalSupporters,
  }) async {
    if (_savingVisibility) return;
    setState(() {
      _savingVisibility = true;
      if (showTrophies != null) _showTrophies = showTrophies;
      if (showPartners != null) _showPartners = showPartners;
      if (showSchedule != null) _showSchedule = showSchedule;
      if (showGlobalSupporters != null) {
        _showGlobalSupporters = showGlobalSupporters;
      }
    });
    try {
      final updated = await _api.updateAcademy(
        _academy.id,
        showTrophies: _showTrophies,
        showPartners: _showPartners,
        showSchedule: _showSchedule,
        showGlobalSupporters: _showGlobalSupporters,
      );
      if (!mounted) return;
      setState(() {
        _academy = updated;
        _showTrophies = updated.showTrophies;
        _showPartners = updated.showPartners;
        _showSchedule = updated.showSchedule;
        _showGlobalSupporters = updated.showGlobalSupporters;
        _savingVisibility = false;
      });
      widget.onUpdated();
      AppFeedback.show(
        context,
        message: 'Visibilidade atualizada na tela do aluno.',
        type: AppFeedbackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingVisibility = false);
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  Future<void> _saveLoginNotice() async {
    if (_savingLoginNotice) return;
    final body = _loginNoticeBodyController.text.trim();
    if (_loginNoticeActive && body.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Para ativar o aviso, preencha o texto do corpo.',
        type: AppFeedbackType.warning,
      );
      return;
    }
    setState(() => _savingLoginNotice = true);
    try {
      final t = _loginNoticeTitleController.text.trim();
      final b = _loginNoticeBodyController.text.trim();
      final u = _loginNoticeUrlController.text.trim();
      final updated = await _api.updateAcademyLoginNotice(
        _academy.id,
        loginNoticeTitle: t.isEmpty ? null : t,
        loginNoticeBody: b.isEmpty ? null : b,
        loginNoticeUrl: u.isEmpty ? null : u,
        loginNoticeActive: _loginNoticeActive,
      );
      if (!mounted) return;
      setState(() {
        _academy = updated;
        _savingLoginNotice = false;
        _loginNoticeTitleController.text = updated.loginNoticeTitle ?? '';
        _loginNoticeBodyController.text = updated.loginNoticeBody ?? '';
        _loginNoticeUrlController.text = updated.loginNoticeUrl ?? '';
        _loginNoticeActive = updated.loginNoticeActive;
      });
      widget.onUpdated();
      final navCtx = context;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!navCtx.mounted) return;
        AppFeedback.show(
          navCtx,
          message: 'Aviso ao abrir o app atualizado.',
          type: AppFeedbackType.success,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingLoginNotice = false);
      final err = userFacingMessage(e);
      final navCtx = context;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!navCtx.mounted) return;
        AppFeedback.show(
          navCtx,
          message: err,
          type: AppFeedbackType.error,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Brasão / logo da academia',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (_academy.logoUrl != null && _academy.logoUrl!.isNotEmpty) ...[
                  Center(
                    child: ClipRRect(
                      borderRadius: AppRadius.cardRadius,
                      child: Image.network(
                        _academyLogoFullUrl(),
                        height: 72,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: AppRadius.cardRadius,
                          ),
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.verticalM,
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _uploadingLogo ? null : _pickAndUploadLogo,
                    icon: _uploadingLogo
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_uploadingLogo ? 'Enviando...' : 'Selecionar imagem'),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Quadro de horários (imagem opcional)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (_academy.scheduleImageUrl != null &&
                    _academy.scheduleImageUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: Image.network(
                        _scheduleImageUrlWithCacheBuster(),
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          alignment: Alignment.center,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.verticalM,
                ],
                if (AuthService().canEditResources())
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed:
                          _uploadingScheduleImage ? null : _pickAndUploadScheduleImage,
                      icon: _uploadingScheduleImage
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: Text(
                        _uploadingScheduleImage ? 'Enviando...' : 'Selecionar imagem',
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Apenas visualização. Apenas administradores, gestores e professores podem alterar.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryOf(context),
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        AppSpacing.verticalM,
        if (AuthService().isAdmin() || AuthService().isManager())
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                child: const Icon(Icons.handshake_outlined, color: AppTheme.primary),
              ),
              title: const Text('Parceiros',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Divulgação para os alunos: empresas e academias parceiras',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PartnerListScreen(academy: _academy),
                ),
              ),
            ),
          ),
        AppSpacing.verticalM,
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visibilidade na tela do aluno',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Defina quais blocos aparecem na home dos alunos desta academia.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar troféus'),
                  subtitle: const Text(
                    'Exibe o acordeon de troféus na tela inicial do aluno.',
                  ),
                  value: _showTrophies,
                  onChanged: _savingVisibility
                      ? null
                      : (value) {
                          _updateHomeVisibility(showTrophies: value);
                        },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar parceiros'),
                  subtitle: const Text(
                    'Exibe o acordeon de parceiros na tela inicial do aluno.',
                  ),
                  value: _showPartners,
                  onChanged: _savingVisibility
                      ? null
                      : (value) {
                          _updateHomeVisibility(showPartners: value);
                        },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar horários da academia'),
                  subtitle: const Text(
                    'Exibe o quadro de horários na tela inicial (quando houver imagem configurada).',
                  ),
                  value: _showSchedule,
                  onChanged: _savingVisibility
                      ? null
                      : (value) {
                          _updateHomeVisibility(showSchedule: value);
                        },
                ),
                if (AuthService().isAdmin())
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar apoiadores do app'),
                    subtitle: const Text(
                      'Exibe o quadro de apoiadores do app (vídeos globais) no final da tela inicial do aluno.',
                    ),
                    value: _showGlobalSupporters,
                    onChanged: _savingVisibility
                        ? null
                        : (value) {
                            _updateHomeVisibility(showGlobalSupporters: value);
                          },
                  ),
              ],
            ),
          ),
        ),
        AppSpacing.verticalM,
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aviso ao abrir o app',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Modal na tela inicial (Campo de treinamento), uma vez por sessão de login, '
                  'para todos os usuários com esta academia — antes do destaque de parceiros.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _loginNoticeTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Título (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 255,
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) =>
                      null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _loginNoticeBodyController,
                  decoration: const InputDecoration(
                    labelText: 'Texto do aviso',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                  maxLength: 8000,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _loginNoticeUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Link opcional',
                    hintText: 'https://…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar aviso ao abrir o app'),
                  subtitle: const Text(
                    'Só aparece se o texto do aviso estiver preenchido.',
                  ),
                  value: _loginNoticeActive,
                  onChanged: _savingLoginNotice
                      ? null
                      : (v) => setState(() => _loginNoticeActive = v),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _savingLoginNotice ? null : _saveLoginNotice,
                    child: _savingLoginNotice
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar aviso'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

