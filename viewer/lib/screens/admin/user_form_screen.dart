import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/user.dart' as models;
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

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
      if (mounted) setState(() {
        _academies = list;
        _loadingAcademies = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAcademies = false);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      final email = values['email'] as String;
      final name = values['name'] as String?;
      final graduation = values['graduation'] as String;
      final academyId = values['academyId'] as String?;
      
      setState(() { _saving = true; _error = null; });
      try {
        if (widget.user == null) {
          await _api.createUser(
            email: email.trim(),
            name: name?.trim().isEmpty == true ? null : name?.trim(),
            graduation: graduation,
            academyId: academyId,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário criado')));
            Navigator.pop(context);
          }
        } else {
          await _api.updateUser(
            widget.user!.id,
            name: name?.trim().isEmpty == true ? null : name?.trim(),
            graduation: graduation,
            academyId: academyId,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário atualizado')));
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) setState(() { _error = userFacingMessage(e); _saving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Editar usuário' : 'Novo usuário'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'email': widget.user?.email ?? '',
            'name': widget.user?.name ?? '',
            'graduation': widget.user?.graduation?.isNotEmpty == true ? widget.user!.graduation : 'white',
            'academyId': widget.user?.academyId,
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormBuilderTextField(
                name: 'email',
                decoration: const InputDecoration(labelText: 'E-mail'),
                enabled: !isEdit,
                keyboardType: TextInputType.emailAddress,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'E-mail é obrigatório'),
                  FormBuilderValidators.email(errorText: 'E-mail inválido'),
                ]),
              ),
              const SizedBox(height: 16),
              FormBuilderTextField(
                name: 'name',
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 16),
              FormBuilderDropdown<String>(
                name: 'graduation',
                decoration: const InputDecoration(labelText: 'Graduação (faixa) *'),
                items: _graduations.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                initialValue: widget.user?.graduation?.isNotEmpty == true ? widget.user!.graduation : 'white',
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'Graduação é obrigatória'),
                ]),
              ),
              const SizedBox(height: 16),
              _loadingAcademies
                  ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
                  : FormBuilderDropdown<String>(
                      name: 'academyId',
                      decoration: const InputDecoration(labelText: 'Academia'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                        ..._academies.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                      ],
                      initialValue: widget.user?.academyId,
                    ),
              if (_error != null) ...[const SizedBox(height: 16), Text(_error!, style: const TextStyle(color: Colors.red))],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
