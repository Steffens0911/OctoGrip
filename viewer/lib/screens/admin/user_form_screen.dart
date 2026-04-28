import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:image_picker/image_picker.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/user.dart' as models;
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/form_utils.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Formulário admin Novo/Editar usuário.
/// A confirmação de senha existe só no cliente; a API recebe apenas o campo `password`.
class UserFormScreen extends StatefulWidget {
  final models.UserModel? user;

  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  static const List<MapEntry<String, String>> _graduations = [
    MapEntry('white', 'Branca'),
    MapEntry('blue', 'Azul'),
    MapEntry('purple', 'Roxa'),
    MapEntry('brown', 'Marrom'),
    MapEntry('black', 'Preta'),
  ];

  static const List<MapEntry<String, String>> _roles = [
    MapEntry('aluno', 'Aluno'),
    MapEntry('professor', 'Professor'),
    MapEntry('gerente_academia', 'Gerente de Academia'),
    MapEntry('administrador', 'Administrador'),
    MapEntry('supervisor', 'Supervisor'),
  ];

  final _api = ApiService();
  final _formKey = GlobalKey<FormBuilderState>();
  List<Academy> _academies = [];
  bool _loadingAcademies = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  final _avatarPicker = ImagePicker();
  XFile? _selectedAvatar;
  Uint8List? _selectedAvatarBytes;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = widget.user?.avatarUrl;
    _loadAcademies();
  }

  String? _absoluteMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    return rawUrl.startsWith('/') ? '${_api.baseUrl}$rawUrl' : rawUrl;
  }

  Future<void> _loadAcademies() async {
    try {
      final list = await _api.getAcademies();
      if (mounted) {
        setState(() {
          _academies = list;
          _loadingAcademies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAcademies = false);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      final email = values['email'] as String;
      final name = values['name'] as String?;
      final password = (values['password'] as String?)?.trim();
      final graduation = values['graduation'] as String?;
      final role = values['role'] as String;
      final isAdmin = AuthService().isAdmin();
      final academyId = isAdmin
          ? (values['academyId'] as String?)
          : (widget.user == null
              ? AuthService().currentUser?.academyId
              : widget.user!.academyId);

      // Validação: graduação obrigatória para professor e aluno
      if ((role == 'professor' || role == 'aluno') &&
          (graduation == null || graduation.isEmpty)) {
        if (mounted) {
          setState(() {
            _error = 'Graduação é obrigatória para $role';
            _saving = false;
          });
        }
        return;
      }

      setState(() {
        _saving = true;
        _error = null;
      });
      try {
        if (widget.user == null) {
          await _api.createUser(
            email: email.trim(),
            name: name?.trim().isEmpty == true ? null : name?.trim(),
            graduation: graduation?.isEmpty == true ? null : graduation,
            role: role,
            password: password?.isEmpty == true ? null : password,
            academyId: academyId,
          );
          if (mounted) {
            AppFeedback.show(
              context,
              message: 'Usuário criado',
              type: AppFeedbackType.success,
            );
            Navigator.pop(context);
          }
        } else {
          final showFreezeControls = isAdmin ||
              (AuthService().isManager() && widget.user!.role == 'aluno');
          final reasonRaw = (values['account_freeze_reason'] as String?)?.trim();
          await _api.updateUser(
            widget.user!.id,
            email: email.trim(),
            name: name?.trim().isEmpty == true ? null : name?.trim(),
            graduation: graduation?.isEmpty == true ? null : graduation,
            role: role,
            password: password?.isEmpty == true ? null : password,
            academyId: isAdmin ? (values['academyId'] as String?) : null,
            sendAccountFreezeFields: showFreezeControls,
            accountFrozen: showFreezeControls
                ? (values['account_frozen'] as bool? ?? false)
                : null,
            accountFreezeReason: showFreezeControls
                ? (reasonRaw?.isEmpty == true ? null : reasonRaw)
                : null,
          );
          if (mounted) {
            AppFeedback.show(
              context,
              message: 'Usuário atualizado',
              type: AppFeedbackType.success,
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = userFacingMessage(e);
            _saving = false;
          });
        }
      }
    }
  }

  Future<void> _pickAvatarFromGallery() async {
    try {
      final image = await _avatarPicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedAvatar = image;
        _selectedAvatarBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  Future<void> _uploadAvatarForEditedUser() async {
    final target = widget.user;
    final image = _selectedAvatar;
    final bytes = _selectedAvatarBytes;
    if (target == null || image == null || bytes == null || _uploadingAvatar) return;
    setState(() => _uploadingAvatar = true);
    try {
      final updated = await _api.uploadUserAvatar(
        target.id,
        bytes: bytes,
        filename: image.name,
        contentType: image.mimeType,
      );
      if (!mounted) return;
      setState(() {
        _uploadingAvatar = false;
        _currentAvatarUrl = updated.avatarUrl;
        _selectedAvatar = null;
        _selectedAvatarBytes = null;
      });
      AppFeedback.show(
        context,
        message: 'Foto do aluno atualizada.',
        type: AppFeedbackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;
    final isAdmin = AuthService().isAdmin();
    final fixedAcademyId =
        isEdit ? widget.user!.academyId : AuthService().currentUser?.academyId;
    final canUploadAvatarInEdit = isEdit &&
        widget.user?.role == 'aluno' &&
        (isAdmin || AuthService().isManager() || AuthService().isProfessor());
    return Scaffold(
      appBar: AppStandardAppBar(
        title: isEdit ? 'Editar usuário' : 'Novo usuário',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'email': widget.user?.email ?? '',
            'name': widget.user?.name ?? '',
            'graduation': widget.user?.graduation?.isNotEmpty == true
                ? widget.user!.graduation
                : null,
            'role': widget.user?.role ?? 'aluno',
            'academyId': isAdmin ? widget.user?.academyId : fixedAcademyId,
            'account_frozen': widget.user?.accountFrozen ?? false,
            'account_freeze_reason': widget.user?.accountFreezeReason ?? '',
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormBuilderTextField(
                name: 'email',
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  helperText:
                      'E-mail único em todo o sistema (todas as academias), sem diferenciar maiúsculas.',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => validateEmail(v?.toString().trim()),
              ),
              const SizedBox(height: 16),
              FormBuilderTextField(
                name: 'name',
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 16),
              FormBuilderTextField(
                name: 'password',
                decoration: InputDecoration(
                  labelText: isEdit ? 'Nova senha' : 'Senha',
                  hintText: isEdit
                      ? 'Deixe em branco para não alterar'
                      : 'Opcional. Mínimo 6 caracteres para o usuário poder entrar.',
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                obscureText: _obscurePassword,
                onChanged: (_) {
                  _formKey.currentState?.fields['password_confirm']?.validate();
                },
                validator: (v) {
                  final s = (v)?.trim() ?? '';
                  if (s.isEmpty) return null;
                  if (s.length < 6) {
                    return 'Senha deve ter no mínimo 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FormBuilderTextField(
                name: 'password_confirm',
                decoration: InputDecoration(
                  labelText: 'Confirmar senha',
                  hintText: isEdit
                      ? 'Repita a nova senha, se for alterá-la'
                      : 'Repita a senha, se a preencheu',
                  suffixIcon: IconButton(
                    tooltip: _obscurePasswordConfirm
                        ? 'Mostrar senha'
                        : 'Ocultar senha',
                    onPressed: () => setState(() =>
                        _obscurePasswordConfirm = !_obscurePasswordConfirm),
                    icon: Icon(
                      _obscurePasswordConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                obscureText: _obscurePasswordConfirm,
                validator: (v) {
                  final pwdRaw =
                      _formKey.currentState?.fields['password']?.value;
                  final pwd = pwdRaw?.toString().trim() ?? '';
                  final cfm = v?.toString().trim() ?? '';
                  if (pwd.isEmpty && cfm.isEmpty) return null;
                  if (pwd.isEmpty && cfm.isNotEmpty) {
                    return 'Preencha a senha ou limpe a confirmação';
                  }
                  if (pwd.isNotEmpty && cfm.isEmpty) {
                    return 'Confirme a senha';
                  }
                  if (pwd != cfm) {
                    return 'As senhas não coincidem';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FormBuilderDropdown<String>(
                name: 'role',
                decoration:
                    const InputDecoration(labelText: 'Categoria (role) *'),
                items: _roles
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                initialValue: widget.user?.role ?? 'aluno',
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(
                      errorText: 'Categoria é obrigatória'),
                ]),
              ),
              const SizedBox(height: 16),
              FormBuilderDropdown<String>(
                name: 'graduation',
                decoration: const InputDecoration(
                  labelText: 'Graduação (faixa)',
                  hintText: 'Obrigatória para Aluno e Professor',
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('— Nenhuma —')),
                  ..._graduations.map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value))),
                ],
                initialValue: widget.user?.graduation?.isNotEmpty == true
                    ? widget.user!.graduation
                    : null,
              ),
              const SizedBox(height: 16),
              _loadingAcademies
                  ? const SizedBox(
                      height: 48,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary)))
                  : isAdmin
                      ? FormBuilderDropdown<String>(
                          name: 'academyId',
                          decoration:
                              const InputDecoration(labelText: 'Academia'),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('— Nenhuma —')),
                            ..._academies.map((a) => DropdownMenuItem(
                                value: a.id, child: Text(a.name))),
                          ],
                          initialValue: widget.user?.academyId,
                        )
                      : FormBuilderDropdown<String>(
                          name: 'academyId',
                          decoration: const InputDecoration(
                            labelText: 'Academia',
                            helperText:
                                'Usuário será vinculado à sua academia.',
                          ),
                          items: fixedAcademyId != null && _academies.isNotEmpty
                              ? _academies
                                  .where((a) => a.id == fixedAcademyId)
                                  .map((a) => DropdownMenuItem(
                                      value: a.id, child: Text(a.name)))
                                  .toList()
                              : [
                                  if (fixedAcademyId != null)
                                    DropdownMenuItem(
                                        value: fixedAcademyId,
                                        child: const Text('Sua academia'))
                                ],
                          initialValue: fixedAcademyId,
                          onChanged: null,
                        ),
              if (canUploadAvatarInEdit) ...[
                const SizedBox(height: 20),
                Text(
                  'Foto de referência (reconhecimento facial)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (_absoluteMediaUrl(_currentAvatarUrl) case final avatarUrl?)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      avatarUrl,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const Text('Aluno sem foto cadastrada.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _uploadingAvatar ? null : _pickAvatarFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_selectedAvatar == null
                      ? 'Selecionar foto do aluno'
                      : 'Trocar foto selecionada'),
                ),
                if (_selectedAvatarBytes != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _selectedAvatarBytes!,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _uploadingAvatar ? null : _uploadAvatarForEditedUser,
                    icon: _uploadingAvatar
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Enviar foto do aluno'),
                  ),
                ],
              ],
              if (isEdit &&
                  (isAdmin ||
                      (AuthService().isManager() &&
                          widget.user?.role == 'aluno'))) ...[
                const SizedBox(height: 20),
                FormBuilderField<bool>(
                  name: 'account_frozen',
                  builder: (field) {
                    return SwitchListTile(
                      title: const Text('Conta congelada'),
                      subtitle: const Text(
                        'O aluno permanece com login, mas não pode treinar nem pontuar até desmarcar.',
                      ),
                      value: field.value ?? false,
                      onChanged: field.didChange,
                    );
                  },
                ),
                FormBuilderTextField(
                  name: 'account_freeze_reason',
                  decoration: const InputDecoration(
                    labelText: 'Motivo (opcional)',
                    hintText: 'Ex.: mensalidade em atraso',
                  ),
                  maxLines: 2,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red))
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
