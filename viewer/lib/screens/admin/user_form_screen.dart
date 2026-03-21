import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/user.dart' as models;
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/form_utils.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAcademies();
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
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Usuário criado')));
            Navigator.pop(context);
          }
        } else {
          await _api.updateUser(
            widget.user!.id,
            name: name?.trim().isEmpty == true ? null : name?.trim(),
            graduation: graduation?.isEmpty == true ? null : graduation,
            role: role,
            password: password?.isEmpty == true ? null : password,
            academyId: isAdmin ? (values['academyId'] as String?) : null,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Usuário atualizado')));
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted)
          setState(() {
            _error = userFacingMessage(e);
            _saving = false;
          });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;
    final isAdmin = AuthService().isAdmin();
    final fixedAcademyId =
        isEdit ? widget.user!.academyId : AuthService().currentUser?.academyId;
    return Scaffold(
      appBar: AppBar(
          title: Text(isEdit ? 'Editar usuário' : 'Novo usuário'),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context))),
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
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormBuilderTextField(
                name: 'email',
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  helperText: 'E-mail deve ser único no sistema.',
                ),
                enabled: !isEdit,
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
                ),
                obscureText: true,
                validator: (v) {
                  final s = (v)?.trim() ?? '';
                  if (s.isEmpty) return null;
                  if (s.length < 6)
                    return 'Senha deve ter no mínimo 6 caracteres';
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
