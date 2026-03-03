import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

/// Formulário criar/editar parceiro da academia.
class PartnerFormScreen extends StatefulWidget {
  final Academy academy;
  final Partner? partner;

  const PartnerFormScreen({super.key, required this.academy, this.partner});

  @override
  State<PartnerFormScreen> createState() => _PartnerFormScreenState();
}

class _PartnerFormScreenState extends State<PartnerFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();
  final _logoUrlController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.partner;
    if (p != null) {
      _nameController.text = p.name;
      _descriptionController.text = p.description ?? '';
      _urlController.text = p.url ?? '';
      _logoUrlController.text = p.logoUrl ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final url = _urlController.text.trim();
    final logoUrl = _logoUrlController.text.trim();
    try {
      if (widget.partner != null) {
        await _api.updatePartner(
          partnerId: widget.partner!.id,
          academyId: widget.academy.id,
          name: name,
          description: description.isEmpty ? null : description,
          url: url.isEmpty ? null : url,
          logoUrl: logoUrl.isEmpty ? null : logoUrl,
        );
      } else {
        await _api.createPartner(
          academyId: widget.academy.id,
          name: name,
          description: description.isEmpty ? null : description,
          url: url.isEmpty ? null : url,
          logoUrl: logoUrl.isEmpty ? null : logoUrl,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.partner != null ? 'Parceiro atualizado' : 'Parceiro criado')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userFacingMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.partner != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar parceiro' : 'Novo parceiro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o nome';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL / site (opcional)',
                  border: OutlineInputBorder(),
                  hintText: 'https://...',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _logoUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL do logo (opcional)',
                  border: OutlineInputBorder(),
                  hintText: 'https://... ou /media/...',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_saving ? 'Salvando...' : (isEdit ? 'Salvar' : 'Criar')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
